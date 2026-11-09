import json
import os
import uuid
import boto3
from datetime import datetime

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

IMAGES_BUCKET = os.environ["IMAGES_BUCKET"]
TABLE_NAME = os.environ["TABLE_NAME"]


def lambda_handler(event, context):
    # CORS headers
    headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "POST,OPTIONS",
        "Content-Type": "application/json",
    }

    try:
        body = json.loads(event.get("body", "{}"))
        file_name = body.get("fileName", "image.jpg")
        file_type = body.get("fileType", "image/jpeg")
        user_id = event.get("requestContext", {}).get("authorizer", {}).get("claims", {}).get("sub", "anonymous")

        # Generate unique image ID
        image_id = str(uuid.uuid4())
        extension = file_name.split(".")[-1].lower()
        s3_key = f"uploads/{user_id}/{image_id}.{extension}"

        # Generate presigned URL (valid 5 minutes)
        presigned_url = s3.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": IMAGES_BUCKET,
                "Key": s3_key,
                "ContentType": file_type,
            },
            ExpiresIn=300,
        )

        # Save initial record to DynamoDB
        table = dynamodb.Table(TABLE_NAME)
        table.put_item(
            Item={
                "imageId": image_id,
                "userId": user_id,
                "s3Key": s3_key,
                "fileName": file_name,
                "caption": "Processing...",
                "status": "PENDING",
                "createdAt": datetime.utcnow().isoformat(),
            }
        )

        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps({
                "imageId": image_id,
                "uploadUrl": presigned_url,
                "s3Key": s3_key,
            }),
        }

    except Exception as e:
        print(f"Error: {e}")
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": str(e)}),
        }
