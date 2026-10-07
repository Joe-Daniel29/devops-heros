# 08 - Session 19 Mini Project

---

# Requirements

Create:

```text
AWS Region
   |
   v
VPC: 10.20.0.0/16
   |
   +-- Public Subnet: 10.20.1.0/24
   |
   +-- Internet Gateway
   |
   +-- Public Route Table
   |
   +-- Route Table Association
   |
   +-- Web Security Group
   |
   +-- EC2 web server (Amazon Linux 2023 + httpd)

S3 bucket (regional, outside the VPC)
   |
   +-- Public access block
   |
   +-- site/index.html object
```

---

# What This Demonstrates

You are now combining:

```text
Cloud fundamentals
        +
Networking
        +
Terraform
```

---

# Project Structure

```text
08-mini-project/
|
|-- README.md
|-- versions.tf
|-- variables.tf
|-- main.tf
|-- outputs.tf
|-- terraform.tfvars.example
|-- .gitignore
```

---

# Architecture

```text
                         Internet
                            |
                            v
                   Internet Gateway
                            |
                    +-------+-------+
                    |      VPC      |
                    |  10.20.0.0/16 |
                    |                |
                    |  Route Table   |
                    |       |        |
                    |       v        |
                    | Public Subnet  |
                    | 10.20.1.0/24  |
                    |       |        |
                    | Security Group |
                    +----------------+
```

---

# Run the Project

Copy variables:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Initialize:

```bash
terraform init
```

Format:

```bash
terraform fmt
```

Validate:

```bash
terraform validate
```

Expected:

```text
Success! The configuration is valid.
```

Plan:

```bash
terraform plan
```

Apply:

```bash
terraform apply
```

Enter:

```text
yes
```

---

# Verify

Show outputs:

```bash
terraform output
```

Expected shape:

```text
instance_id = "i-..."
instance_public_ip = "x.x.x.x"
s3_bucket_name = "session19-mini-assets-..."
security_group_id = "sg-..."
subnet_id = "subnet-..."
vpc_cidr = "10.20.0.0/16"
vpc_id = "vpc-..."
website_url = "http://x.x.x.x"
```

Show resources:

```bash
terraform state list
```

Expected:

```text
data.aws_ami.al2023
aws_instance.web
aws_internet_gateway.main
aws_route_table.public
aws_route_table_association.public
aws_s3_bucket.assets
aws_s3_bucket_public_access_block.assets
aws_s3_object.index
aws_security_group.web
aws_subnet.public
aws_vpc.main
```

---

# AWS CLI Verification (Optional -> You can check directly in dashboard too)

VPC:

```bash
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=session19-mini-vpc" \
  --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,State:State}'
```

Subnet:

```bash
aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=session19-mini-public-subnet" \
  --query 'Subnets[].{SubnetId:SubnetId,Cidr:CidrBlock,AZ:AvailabilityZone}'
```

Route table:

```bash
aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=session19-mini-public-rt" \
  --query 'RouteTables[].{RouteTableId:RouteTableId,VpcId:VpcId}'
```

Security group:

```bash
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=session19-mini-web-sg" \
  --query 'SecurityGroups[].{GroupId:GroupId,VpcId:VpcId}'
```

---

# Cleanup

```bash
terraform plan -destroy
terraform destroy
```

Enter:

```text
yes
```

Expected:

```text
Destroy complete! Resources: 10 destroyed.
```

---

# Extension - EC2 and S3 (implemented)

`main.tf` now also creates an EC2 web server (`aws_instance.web`) in the public
subnet and an S3 bucket (`aws_s3_bucket.assets`). Check the site with
`curl $(terraform output -raw website_url)`.

The instance should use:

```text
Public Subnet
       |
Security Group
       |
EC2
```

Questions to think about:

1. Which subnet should the EC2 instance use?
2. Which security group should it use?
3. Why does a public subnet need a route to the Internet Gateway?
4. What else is required for an EC2 instance to be reachable from the internet?
5. Why should SSH not normally be open to `0.0.0.0/0`?

Do not add EC2 until the VPC lab works.

---

# Interview Questions

Explain these without looking at notes:

```text
1. IaaS vs PaaS vs SaaS
2. Region vs Availability Zone
3. VPC vs Subnet
4. Public vs Private Subnet
5. Route Table
6. Internet Gateway
7. Security Group
8. Terraform
9. terraform plan vs terraform apply
10. terraform state
11. terraform destroy
```
