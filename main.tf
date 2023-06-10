terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = "us-east-1"
}

#region  > S3 Bucket Code <
resource "aws_s3_bucket" "main_s3" {
  bucket        = "artkuch.com"
  force_destroy = true
  tags = {
    Name        = "MCR Bucket"
    Environment = "PROD"
  }
}

# Upload frontend content to s3 config block
resource "aws_s3_object" "s3upload" {
  for_each = fileset("./frontend/", "**")
  bucket   = aws_s3_bucket.main_s3.id
  key      = each.value
  source   = "./frontend/${each.value}"
  etag     = filemd5("./frontend/${each.value}")
}
locals {
  mime_types = {
    ".html" = "text/html"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".json" = "application/json"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
  }
}
resource "aws_s3_bucket_policy" "main_bucket_policy" {
  bucket = aws_s3_bucket.main_s3.id
  policy = jsonencode({
    "Version" : "2008-10-17",
    "Id" : "PolicyForCloudFrontPrivateContent",
    "Statement" : [
      {
        "Sid" : "AllowCloudFrontServicePrincipal",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : [
            "cloudfront.amazonaws.com",
            "apigateway.amazonaws.com"
          ]
        },
        "Action" : "s3:GetObject",
        "Resource" : "${aws_s3_bucket.main_s3.arn}/*",
        "Condition" : {
          "StringEquals" : {
            "AWS:SourceArn" : "arn:aws:cloudfront::660226592577:distribution/${aws_cloudfront_distribution.cdn_distribution.id}"
          }
        }
      }
    ]
  })
}
resource "aws_s3_bucket_website_configuration" "main_s3_config" {
  bucket = aws_s3_bucket.main_s3.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "index.html"
  }
}
resource "aws_s3_bucket_cors_configuration" "example" {
  bucket = aws_s3_bucket.main_s3.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
  }
}

# Second bucket used to redirect
resource "aws_s3_bucket" "secondary_s3" {
  bucket        = "www.artkuch.com"
  force_destroy = true
}
resource "aws_s3_bucket_website_configuration" "s3_redirect" {
  bucket = "www.artkuch.com"
  redirect_all_requests_to {
    host_name = "artkuch.com"
  }
}
#endregion
#region  > Lambda Function Python <
# Zip the Lambda function's code
data "archive_file" "lambda_function_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  source_dir  = "${path.module}/lambda_function_python"
}
# Define the Lambda function
resource "aws_lambda_function" "lambda_python" {
  function_name    = "lambda_function_python"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function_python.lambda_handler"
  runtime          = "python3.9"
  filename         = data.archive_file.lambda_function_zip.output_path
  source_code_hash = data.archive_file.lambda_function_zip.output_base64sha256
}
# Define Lambda function IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "lambda_permissions_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}
# Attach Lambda execution policy to the IAM role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# Policy to allow access to DynamoDB
resource "aws_iam_policy" "dynamodb_policy" {
  name = "dynamodb_policy_for_lambdafunction"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:dynamodb:us-east-1:660226592577:table/lambda-apigateway-ddb"
      }
    ]
  })
}
# Attach DynamoDB Lambda execution policy to role
resource "aws_iam_role_policy_attachment" "dynamodb_policy_attachment" {
  policy_arn = aws_iam_policy.dynamodb_policy.arn
  role       = aws_iam_role.lambda_role.name
}
#endregion
#region  > DynamoDB Table <
resource "aws_dynamodb_table" "dynamo_db_table" {
  name           = "lambda-apigateway-ddb"
  billing_mode   = "PAY_PER_REQUEST"
  read_capacity  = 0
  write_capacity = 0
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
}
#creating a new item in the "example" DynamoDB table with the "id" attribute set to "visits" and the "count" attribute set to 0
resource "aws_dynamodb_table_item" "ddb_table_item" {
  table_name = aws_dynamodb_table.dynamo_db_table.name
  hash_key   = aws_dynamodb_table.dynamo_db_table.hash_key
  item       = <<ITEM
{
  "id" : {"S": "visits"},
  "count" : {"N": "0"}
}
ITEM
}
#endregion
#region  > API Gateway <
# REST API
resource "aws_api_gateway_rest_api" "mcr_rest" {
  name        = "MCR_API"
  description = "API for My Cloud Resume"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}
# Resource
resource "aws_api_gateway_resource" "mcr_root" {
  rest_api_id = aws_api_gateway_rest_api.mcr_rest.id
  parent_id   = aws_api_gateway_rest_api.mcr_rest.root_resource_id
  path_part   = "lambda"
}
# Deploy the API to 'prod' stage
resource "aws_api_gateway_deployment" "example" {
  depends_on  = [aws_api_gateway_integration.example_get, aws_api_gateway_integration.example_post, aws_api_gateway_integration.example_options]
  rest_api_id = aws_api_gateway_rest_api.mcr_rest.id
  stage_name  = "prod"
  description = "Deploy to prod stage"
}
# Permissions to invoke LF
resource "aws_lambda_permission" "example" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_python.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.mcr_rest.execution_arn}/*/*"
}
# GET method
resource "aws_api_gateway_method" "example_get" {
  rest_api_id   = aws_api_gateway_rest_api.mcr_rest.id
  resource_id   = aws_api_gateway_resource.mcr_root.id
  http_method   = "GET"
  authorization = "NONE"
}
# POST method
resource "aws_api_gateway_method" "example_post" {
  rest_api_id   = aws_api_gateway_rest_api.mcr_rest.id
  resource_id   = aws_api_gateway_resource.mcr_root.id
  http_method   = "POST"
  authorization = "NONE"
}
# Lambda proxy integration for GET method
resource "aws_api_gateway_integration" "example_get" {
  rest_api_id             = aws_api_gateway_rest_api.mcr_rest.id
  resource_id             = aws_api_gateway_resource.mcr_root.id
  http_method             = aws_api_gateway_method.example_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_python.invoke_arn
}
# Lambda proxy integration for POST method
resource "aws_api_gateway_integration" "example_post" {
  rest_api_id             = aws_api_gateway_rest_api.mcr_rest.id
  resource_id             = aws_api_gateway_resource.mcr_root.id
  http_method             = aws_api_gateway_method.example_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_python.invoke_arn
}
# CORS config - OPTIONS method with MOCK and integration/method responses
# Add OPTIONS
resource "aws_api_gateway_method" "example_options" {
  rest_api_id   = aws_api_gateway_rest_api.mcr_rest.id
  resource_id   = aws_api_gateway_resource.mcr_root.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}
# Add MOCK integration for OPTIONS
resource "aws_api_gateway_integration" "example_options" {
  rest_api_id       = aws_api_gateway_rest_api.mcr_rest.id
  resource_id       = aws_api_gateway_resource.mcr_root.id
  http_method       = aws_api_gateway_method.example_options.http_method
  type              = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}
# Method response for OPTIONS
resource "aws_api_gateway_method_response" "example_options" {
  rest_api_id = aws_api_gateway_rest_api.mcr_rest.id
  resource_id = aws_api_gateway_resource.mcr_root.id
  http_method = aws_api_gateway_method.example_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}
# Integration response for OPTIONS
resource "aws_api_gateway_integration_response" "example_options" {
  rest_api_id = aws_api_gateway_rest_api.mcr_rest.id
  resource_id = aws_api_gateway_resource.mcr_root.id
  http_method = aws_api_gateway_method.example_options.http_method
  status_code = aws_api_gateway_method_response.example_options.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  response_templates = { "application/json" = "" }
}
#endregion

#region  > CloudFront  <
# CloudFront origin access control for cdn_distribution main_s3 bucket origin artkuch.com.s3.us-east-1.amazonaws.com
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "artkuch.com.s3.us-east-1.amazonaws.com"
  description                       = ""
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


#Origin access control for main_s3 bucket
resource "aws_cloudfront_distribution" "cdn_distribution" {
  aliases = [
    "artkuch.com"
  ]
  default_root_object = "index.html"

  origin {
    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_keepalive_timeout = 5
      origin_protocol_policy   = "match-viewer"
      origin_read_timeout      = 30
      origin_ssl_protocols = [
        "TLSv1.2"
      ]
    }

    domain_name = "wpl4v1vlpj.execute-api.us-east-1.amazonaws.com"
    origin_id   = "wpl4v1vlpj.execute-api.us-east-1.amazonaws.com"
    origin_path = "/prod"
  }
  origin {
    domain_name = "artkuch.com.s3.us-east-1.amazonaws.com"
    origin_id   = "artkuch.com.s3-website-us-east-1.amazonaws.com"
    origin_path              = ""
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods        = ["HEAD", "GET", "OPTIONS"]
    cached_methods         = ["HEAD", "GET", "OPTIONS"]
    compress               = true
    smooth_streaming       = false
    target_origin_id       = "artkuch.com.s3-website-us-east-1.amazonaws.com"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  }
  ordered_cache_behavior {
    path_pattern           = "/prod/lambdaddb/*"
    compress               = true
    smooth_streaming       = false
    target_origin_id       = "wpl4v1vlpj.execute-api.us-east-1.amazonaws.com"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    allowed_methods = [
      "HEAD",
      "GET",
      "OPTIONS"
    ]
    cached_methods = [
      "HEAD",
      "GET",
      "OPTIONS"
    ]
  }
  comment     = ""
  price_class = "PriceClass_All"
  enabled     = true
  viewer_certificate {
    acm_certificate_arn            = "arn:aws:acm:us-east-1:660226592577:certificate/52ca9367-94e8-4533-8afd-5ec400654d2f"
    cloudfront_default_certificate = false
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  http_version    = "http2"
  is_ipv6_enabled = true
}

#endregion

#region  > Route53     <
resource "aws_acm_certificate" "cert" {
  domain_name       = "artkuch.com"
  validation_method = "DNS"
  tags = {
    Name = "artkuch.com"
  }
  lifecycle {
    create_before_destroy = true
  }
}

#new
# Import CloudFront distribution as a data source
data "aws_cloudfront_distribution" "cdn_distribution" {
  id = aws_cloudfront_distribution.cdn_distribution.id
}

# Import Route 53 zone as a data source
data "aws_route53_zone" "zone" {
  zone_id      = "Z0717253GTJDVPAT1PZN"
  private_zone = false
}


# Create Route 53 A record for CloudFront using the dynamically retrieved CloudFront domain name
resource "aws_route53_record" "cloudfront_record" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "artkuch.com"
  type    = "A"
  alias {
    name                   = data.aws_cloudfront_distribution.cdn_distribution.domain_name
    zone_id                = data.aws_cloudfront_distribution.cdn_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
#endregion