output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID of the web security group."
  value       = aws_security_group.web.id
}

output "instance_id" {
  description = "ID of the EC2 web server."
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Public IPv4 address of the EC2 web server."
  value       = aws_instance.web.public_ip
}

output "website_url" {
  description = "URL of the page served by the EC2 web server."
  value       = "http://${aws_instance.web.public_ip}"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket created for the project."
  value       = aws_s3_bucket.assets.bucket
}
