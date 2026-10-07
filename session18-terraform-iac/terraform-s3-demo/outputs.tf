output "bucket_name" {
  description = "Name of the S3 bucket."
  value       = aws_s3_bucket.devops553.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.devops553.arn
}

output "bucket_region" {
  description = "AWS region of the S3 bucket."
  value       = aws_s3_bucket.devops553.region
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket."
  value       = aws_s3_bucket.devops553.bucket_regional_domain_name
}

output "versioning_status" {
  description = "Versioning status of the S3 bucket."
  value       = aws_s3_bucket_versioning.devops553.versioning_configuration[0].status
}
