import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
    table = dynamodb.Table('lambda-apigateway')

    http_method = event['httpMethod']

    logger.info(f'HTTP Method: {http_method}')

    if http_method == 'POST':
        response = table.update_item(
            Key={
                'id': 'visits'
            },
            UpdateExpression='ADD #count :increment',
            ExpressionAttributeNames={
                '#count': 'count'
            },
            ExpressionAttributeValues={
                ':increment': 1
            },
            ReturnValues='UPDATED_NEW'
        )
        count = response['Attributes']['count']
        logger.info(f'Updated count: {count}')

    elif http_method == 'GET':
        response = table.get_item(
            Key={
                'id': 'visits'
            }
        )
        count = response['Item']['count']
        logger.info(f'Fetched count: {count}')

    else:
        return {
            "statusCode": 400,
            "body": "Invalid request method"
        }

    return {
        "statusCode": 200,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Credentials": "true",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Allow-Methods": "OPTIONS,GET,POST"
        },
        "body": str(count)
    }
