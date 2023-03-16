import boto3

def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('lambda-apigateway')
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
    return {
        "statusCode": 200,
        "body": "Visitor count: " + str(count)
    }
