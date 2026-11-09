variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "piccaption"
}

variable "bedrock_model_id" {
  description = "Bedrock model ID for caption generation"
  type        = string
  default     = "anthropic.claude-haiku-4-5"
}
