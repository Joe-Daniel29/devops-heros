resource "aws_s3_bucket" "devops553" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Session18"
  }
}

# Keep every version of every object (protects against accidental overwrite/delete)
resource "aws_s3_bucket_versioning" "devops553" {
  bucket = aws_s3_bucket.devops553.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# Encrypt all objects at rest with S3-managed keys (SSE-S3 / AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "devops553" {
  bucket = aws_s3_bucket.devops553.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# The bucket must never be public
resource "aws_s3_bucket_public_access_block" "devops553" {
  bucket = aws_s3_bucket.devops553.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
