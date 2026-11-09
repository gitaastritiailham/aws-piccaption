# -------------------------------------------------------
# Lambda: get-presigned-url
# -------------------------------------------------------
data "archive_file" "get_presigned_url" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/get_presigned_url"
  output_path = "${path.module}/../lambda/get_presigned_url.zip"
}

resource "aws_lambda_function" "get_presigned_url" {
  function_name    = "${var.project_name}-get-presigned-url"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.get_presigned_url.output_path
  source_code_hash = data.archive_file.get_presigned_url.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      IMAGES_BUCKET = aws_s3_bucket.images.bucket
      TABLE_NAME    = aws_dynamodb_table.images.name
    }
  }
}

# -------------------------------------------------------
# Lambda: get-images
# -------------------------------------------------------
data "archive_file" "get_images" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/get_images"
  output_path = "${path.module}/../lambda/get_images.zip"
}

resource "aws_lambda_function" "get_images" {
  function_name    = "${var.project_name}-get-images"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.get_images.output_path
  source_code_hash = data.archive_file.get_images.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      IMAGES_BUCKET = aws_s3_bucket.images.bucket
      TABLE_NAME    = aws_dynamodb_table.images.name
    }
  }
}

# -------------------------------------------------------
# Lambda: caption-processor (SQS → Bedrock → DynamoDB)
# -------------------------------------------------------
data "archive_file" "caption_processor" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/caption_processor"
  output_path = "${path.module}/../lambda/caption_processor.zip"
}

resource "aws_lambda_function" "caption_processor" {
  function_name    = "${var.project_name}-caption-processor"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.caption_processor.output_path
  source_code_hash = data.archive_file.caption_processor.output_base64sha256
  timeout          = 120

  reserved_concurrent_executions = 5

  environment {
    variables = {
      IMAGES_BUCKET    = aws_s3_bucket.images.bucket
      TABLE_NAME       = aws_dynamodb_table.images.name
      BEDROCK_MODEL_ID = var.bedrock_model_id
    }
  }
}

resource "aws_lambda_event_source_mapping" "sqs_to_caption" {
  event_source_arn = aws_sqs_queue.caption_queue.arn
  function_name    = aws_lambda_function.caption_processor.arn
  batch_size       = 1
  enabled          = true
}
