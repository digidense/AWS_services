import boto3
import os

def handler(event, context):
    # Get current region from Lambda context
    region = context.invoked_function_arn.split(":")[3]
    client = boto3.client("datasync", region_name=region)
    response = client.start_task_execution(
        TaskArn=os.environ["DATASYNC_TASK_ARN"]
    )
    return response
