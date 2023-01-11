import boto3
import os
import json
  
def get_secret_value(name, version=None):
    """Gets the value of a secret.

    Version (if defined) is used to retrieve a particular version of
    the secret.

    """
    secret = os.environ['vpc_peering']
    secrets_client = boto3.client("secretsmanager")
    kwargs = {'SecretId': name}
    if version is not None:
        kwargs['VersionStage'] = version
    response = secrets_client.get_secret_value(**kwargs)
    return response
    
def lambda_handler(event, context):
    secret = os.environ['vpc_peering']
    result = get_secret_value(secret)
    return {
        'statusCode' : 200,
        'body': json.dumps(result, default=str)
    }