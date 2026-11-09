# -------------------------------------------------------
# S3 Bucket: Image Storage
# -------------------------------------------------------
resource "aws_s3_bucket" "images" {
  bucket        = "${var.project_name}-images-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_cors_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    id     = "move-old-images-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_notification" "images" {
  bucket = aws_s3_bucket.images.id

  queue {
    queue_arn     = aws_sqs_queue.caption_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".jpg"
  }

  queue {
    queue_arn     = aws_sqs_queue.caption_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".jpeg"
  }

  queue {
    queue_arn     = aws_sqs_queue.caption_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".png"
  }

  depends_on = [aws_sqs_queue_policy.caption_queue]
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -------------------------------------------------------
# S3 Bucket: Frontend
# -------------------------------------------------------
resource "aws_s3_bucket" "frontend" {
  bucket        = "${var.project_name}-frontend-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_id" "suffix" {
  byte_length = 4
}
