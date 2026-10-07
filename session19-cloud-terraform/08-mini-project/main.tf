locals {
  common_tags = {
    Project   = var.project_name
    Session   = "19"
    ManagedBy = "Terraform"
  }

  index_html = <<-HTML
    <html>
      <head><title>Session 19 - Cloud and Terraform</title></head>
      <body>
        <h1>Hello from Terraform!</h1>
        <p>EC2 web server in ${var.project_name}-public-subnet (${var.aws_region})</p>
      </body>
    </html>
  HTML
}

# ---------------------------------------------------------------- network ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-subnet"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --------------------------------------------------------------- security ---
resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Allow HTTP and HTTPS for Session 19"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound IPv4"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-web-sg"
  })
}

# ---------------------------------------------------------------- compute ---
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y httpd
    cat > /var/www/html/index.html <<'PAGE'
    ${local.index_html}
    PAGE
    systemctl enable --now httpd
  EOF

  user_data_replace_on_change = true

  # Explicit dependency: the instance needs the internet route in place
  # before boot so user_data can download httpd.
  depends_on = [aws_route_table_association.public]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-web"
  })
}

# ---------------------------------------------------------------- storage ---
resource "aws_s3_bucket" "assets" {
  bucket_prefix = "${var.project_name}-assets-"
  force_destroy = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-assets"
  })
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.assets.id
  key          = "site/index.html"
  content      = local.index_html
  content_type = "text/html"
}
