# -------------------------------------------------------
# SQS: Caption Queue (S3 → SQS → Lambda)
# -------------------------------------------------------
resource "aws_sqs_queue" "caption_queue" {
  name                       = "${var.project_name}-caption-queue"
  visibility_timeout_seconds = 120
  message_retention_seconds  = 3600
  receive_wait_time_seconds  = 20

  tags = {
    Project = var.project_name
  }
}

resource "aws_sqs_queue_policy" "caption_queue" {
  queue_url = aws_sqs_queue.caption_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3ToSendMessage"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.caption_queue.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.images.arn
          }
        }
      }
    ]
  })
}
