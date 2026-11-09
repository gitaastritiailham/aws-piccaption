import json
import os
import base64
import boto3

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
bedrock = boto3.client("bedrock-runtime", region_name="us-east-1")

IMAGES_BUCKET = os.environ["IMAGES_BUCKET"]
TABLE_NAME = os.environ["TABLE_NAME"]
BEDROCK_MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "anthropic.claude-haiku-4-5")


def get_caption_from_bedrock(image_bytes: bytes, content_type: str = "image/jpeg") -> str:
    """Send image to Bedrock Claude and get caption."""
    image_base64 = base64.standard_b64encode(image_bytes).decode("utf-8")

    # Map content type to Bedrock media type
    media_type_map = {
        "image/jpeg": "image/jpeg",
        "image/jpg": "image/jpeg",
        "image/png": "image/png",
        "image/gif": "image/gif",
        "image/webp": "image/webp",
    }
    media_type = media_type_map.get(content_type, "image/jpeg")

    payload = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 200,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": media_type,
                            "data": image_base64,
                        },
                    },
                    {
                        "type": "text",
                        "text": "Describe this image in one clear, concise sentence. Focus on the main subject and key details. Return only the description, no extra text.",
                    },
                ],
            }
        ],
    }

    response = bedrock.invoke_model(
        modelId=BEDROCK_MODEL_ID,
        contentType="application/json",
        accept="application/json",
        body=json.dumps(payload),
    )

    result = json.loads(response["body"].read())
    return result["content"][0]["text"].strip()


def extract_s3_key_from_event(record: dict) -> str:
    """Extract S3 key from SQS message body (which contains S3 event)."""
    body = json.loads(record["body"])
    s3_event = body["Records"][0]["s3"]
    return s3_event["object"]["key"]


def get_image_id_from_key(s3_key: str) -> str:
    """Extract imageId from S3 key: uploads/{userId}/{imageId}.{ext}"""
    filename = s3_key.split("/")[-1]
    return filename.rsplit(".", 1)[0]


def lambda_handler(event, context):
    table = dynamodb.Table(TABLE_NAME)

    for record in event.get("Records", []):
        image_id = None
        try:
            s3_key = extract_s3_key_from_event(record)
            image_id = get_image_id_from_key(s3_key)
            print(f"Processing image: {image_id}, key: {s3_key}")

            # Download image from S3
            s3_response = s3.get_object(Bucket=IMAGES_BUCKET, Key=s3_key)
            image_bytes = s3_response["Body"].read()
            content_type = s3_response.get("ContentType", "image/jpeg")

            # Get caption from Bedrock
            caption = get_caption_from_bedrock(image_bytes, content_type)
            print(f"Caption generated: {caption}")

            # Update DynamoDB record
            table.update_item(
                Key={"imageId": image_id},
                UpdateExpression="SET caption = :caption, #st = :status",
                ExpressionAttributeNames={"#st": "status"},
                ExpressionAttributeValues={
                    ":caption": caption,
                    ":status": "DONE",
                },
            )

        except Exception as e:
            print(f"Error processing record: {e}")
            if image_id:
                # Mark as failed in DynamoDB
                try:
                    table.update_item(
                        Key={"imageId": image_id},
                        UpdateExpression="SET caption = :caption, #st = :status",
                        ExpressionAttributeNames={"#st": "status"},
                        ExpressionAttributeValues={
                            ":caption": "Failed to generate caption",
                            ":status": "FAILED",
                        },
                    )
                except Exception as update_err:
                    print(f"Failed to update error status: {update_err}")
            raise e
