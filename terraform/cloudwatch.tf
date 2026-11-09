# -------------------------------------------------------
# CloudWatch: Log Groups for Lambda
# -------------------------------------------------------
resource "aws_cloudwatch_log_group" "presigned_url" {
  name              = "/aws/lambda/${aws_lambda_function.get_presigned_url.function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "get_images" {
  name              = "/aws/lambda/${aws_lambda_function.get_images.function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "caption_processor" {
  name              = "/aws/lambda/${aws_lambda_function.caption_processor.function_name}"
  retention_in_days = 7
}

# -------------------------------------------------------
# CloudWatch: Alarm - Lambda errors
# -------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "caption_errors" {
  alarm_name          = "${var.project_name}-caption-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "Caption processor Lambda errors > 3 in 5 minutes"

  dimensions = {
    FunctionName = aws_lambda_function.caption_processor.function_name
  }
}
