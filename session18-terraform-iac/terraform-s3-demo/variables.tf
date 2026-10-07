variable "aws_region" {
  type        = string
  description = "AWS region where the S3 bucket will be created."
  default     = "ap-south-1"
}

variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket (must be globally unique)."
  default     = "yatri1107"
}

variable "environment" {
  type        = string
  description = "Environment tag applied to the bucket."
  default     = "dev"
}

variable "versioning_enabled" {
  type        = bool
  description = "Enable S3 object versioning on the bucket."
  default     = true
}
