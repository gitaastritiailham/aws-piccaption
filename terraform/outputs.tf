output "frontend_url" {
  description = "Frontend URL served over HTTPS by CloudFront"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "api_url" {
  description = "API Gateway URL"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "images_bucket_name" {
  description = "S3 bucket name for images"
  value       = aws_s3_bucket.images.bucket
}

output "frontend_bucket_name" {
  description = "S3 bucket name for frontend"
  value       = aws_s3_bucket.frontend.bucket
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "Cognito App Client ID"
  value       = aws_cognito_user_pool_client.main.id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.images.name
}

output "sqs_queue_url" {
  description = "SQS Queue URL"
  value       = aws_sqs_queue.caption_queue.url
}
