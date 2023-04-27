import unittest
from unittest.mock import MagicMock
from moto import mock_dynamodb2
import boto3
import json

# Import the lambda_handler from your original Lambda function file
from backend.LambdaFunctionOverHttps import lambda_handler

@mock_dynamodb2
class TestLambdaFunction(unittest.TestCase):
    def setUp(self):
        self.dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
        self.table_name = 'lambda-apigateway'

        # Delete the table if it already exists
        try:
            self.dynamodb.Table(self.table_name).delete()
        except self.dynamodb.meta.client.exceptions.ResourceNotFoundException:
            pass

        # Create the table
        self.dynamodb.create_table(
            TableName=self.table_name,
            KeySchema=[{'AttributeName': 'id', 'KeyType': 'HASH'}],
            AttributeDefinitions=[{'AttributeName': 'id', 'AttributeType': 'S'}],
            ProvisionedThroughput={'ReadCapacityUnits': 1, 'WriteCapacityUnits': 1}
        )
        self.table = self.dynamodb.Table(self.table_name)
        self.table.put_item(Item={'id': 'visits', 'count': 0})

    def test_post_request(self):
        event = {'httpMethod': 'POST'}
        response = lambda_handler(event, None)
        body = response['body']

        self.assertEqual(response['statusCode'], 200)
        self.assertEqual(body, "1")

    def test_get_request(self):
        event = {'httpMethod': 'GET'}
        response = lambda_handler(event, None)
        body = response['body']

        self.assertEqual(response['statusCode'], 200)
        self.assertEqual(body, "0")

if __name__ == '__main__':
    unittest.main()
