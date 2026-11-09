import json
import os
import boto3
from boto3.dynamodb.conditions import Key

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

IMAGES_BUCKET = os.environ["IMAGES_BUCKET"]
TABLE_NAME = os.environ["TABLE_NAME"]


def lambda_handler(event, context):
    headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "GET,OPTIONS",
        "Content-Type": "application/json",
    }

    try:
        user_id = event.get("requestContext", {}).get("authorizer", {}).get("claims", {}).get("sub", "anonymous")

        table = dynamodb.Table(TABLE_NAME)

        # Query by userId using GSI
        response = table.query(
            IndexName="userId-createdAt-index",
            KeyConditionExpression=Key("userId").eq(user_id),
            ScanIndexForward=False,  # newest first
            Limit=50,
        )

        images = []
        for item in response.get("Items", []):
            # Generate presigned URL for viewing (valid 1 hour)
            view_url = s3.generate_presigned_url(
                "get_object",
                Params={
                    "Bucket": IMAGES_BUCKET,
                    "Key": item["s3Key"],
                },
                ExpiresIn=3600,
            )
            images.append({
                "imageId": item["imageId"],
                "fileName": item.get("fileName", ""),
                "caption": item.get("caption", ""),
                "status": item.get("status", "PENDING"),
                "createdAt": item.get("createdAt", ""),
                "viewUrl": view_url,
            })

        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps({"images": images}),
        }

    except Exception as e:
        print(f"Error: {e}")
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": str(e)}),
        }
