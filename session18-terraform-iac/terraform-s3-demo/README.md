# Terraform S3 Bucket Demo

Create an AWS S3 bucket with Terraform and walk through the complete Terraform workflow:
`init → fmt → validate → plan → apply → show → output → destroy`.

The bucket is created in **us-east-1** with versioning, default encryption (SSE-S3) and Block Public Access enabled.

## Project Structure

```text
terraform-s3-demo/
├── main.tf              # S3 bucket + versioning + encryption + public access block
├── variables.tf         # input variable declarations (type, description, default)
├── outputs.tf           # values printed after apply / via `terraform output`
├── provider.tf          # terraform block (version constraints) + AWS provider
├── terraform.tfvars     # actual values for the variables
├── README.md            # this file
├── .gitignore           # ignores .terraform/, *.tfstate, crash logs
└── .terraform.lock.hcl  # provider version lock (created by terraform init)
```

## Architecture

```text
provider.tf ──► AWS provider (hashicorp/aws ~> 6.0, region = var.aws_region)
     │
variables.tf ◄── terraform.tfvars  (aws_region, bucket_name, environment, versioning_enabled)
     │
main.tf
  ├── aws_s3_bucket.devops553                                      bucket "joe-tf-s3-demo-24bcs10214"
  ├── aws_s3_bucket_versioning.devops553                           Status = Enabled
  ├── aws_s3_bucket_server_side_encryption_configuration.devops553 AES256 + bucket key
  └── aws_s3_bucket_public_access_block.devops553                  all 4 blocks = true
     │
outputs.tf ──► bucket_name, bucket_arn, bucket_region, bucket_regional_domain_name, versioning_status
     │
terraform.tfstate (local) ── records the real resource IDs
```

## Files

### provider.tf

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

### variables.tf

| Variable | Type | Default | Description |
|---|---|---|---|
| `aws_region` | string | `ap-south-1` | AWS region for the bucket |
| `bucket_name` | string | `yatri1107` | Globally unique bucket name |
| `environment` | string | `dev` | Environment tag |
| `versioning_enabled` | bool | `true` | Enable object versioning |

### terraform.tfvars

Values in `terraform.tfvars` are loaded automatically and override the defaults:

```hcl
aws_region         = "us-east-1"
bucket_name        = "joe-tf-s3-demo-24bcs10214"
environment        = "dev"
versioning_enabled = true
```

### main.tf

```hcl
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

resource "aws_s3_bucket_versioning" "devops553" {
  bucket = aws_s3_bucket.devops553.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "devops553" {
  bucket = aws_s3_bucket.devops553.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "devops553" {
  bucket = aws_s3_bucket.devops553.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

* Since AWS provider v4, bucket settings (versioning, encryption, policy, lifecycle...) are **separate resources** that reference the bucket by `aws_s3_bucket.devops553.id`. This reference creates an **implicit dependency**, so Terraform always creates the bucket first.
* `force_destroy = true` lets `terraform destroy` delete the bucket even if it still contains objects (and object versions). Handy for a demo; leave it `false` for real data.

### outputs.tf

| Output | Value |
|---|---|
| `bucket_name` | `aws_s3_bucket.devops553.bucket` |
| `bucket_arn` | `aws_s3_bucket.devops553.arn` |
| `bucket_region` | `aws_s3_bucket.devops553.region` |
| `bucket_regional_domain_name` | `aws_s3_bucket.devops553.bucket_regional_domain_name` |
| `versioning_status` | `aws_s3_bucket_versioning.devops553.versioning_configuration[0].status` |

## Prerequisites

```bash
terraform -version          # Terraform v1.16.4
aws --version               # aws-cli/2.37.5
aws configure               # access key, secret, default region us-east-1, output json
aws sts get-caller-identity # confirms which account/user Terraform will use
```

## Complete Workflow

### 1. `terraform init`

Downloads the AWS provider into `.terraform/` and uses the version pinned in `.terraform.lock.hcl` (v6.66.0).

```bash
terraform init
```

```text
Initializing the backend...
Initializing provider plugins...
- Reusing previous version of hashicorp/aws from the dependency lock file
- Installing hashicorp/aws v6.66.0...
- Installed hashicorp/aws v6.66.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

### 2. `terraform fmt`

Rewrites `.tf` files in the canonical style (2-space indent, aligned `=`) and prints the files it changed.

```bash
terraform fmt
terraform fmt -check    # CI-friendly: prints nothing and exits 0 when already formatted
```

```text
main.tf
outputs.tf
variables.tf
```

### 3. `terraform validate`

Checks syntax, references and argument names without contacting AWS.

```bash
terraform validate
```

```text
Success! The configuration is valid.
```

### 4. `terraform plan`

Compares the configuration with the state (empty) and shows what will happen.

```bash
terraform plan
```

```text
  # aws_s3_bucket.devops553 will be created
  + resource "aws_s3_bucket" "devops553" {
      + arn                         = (known after apply)
      + bucket                      = "joe-tf-s3-demo-24bcs10214"
      + force_destroy               = true
      + region                      = "us-east-1"
      ...
    }

  # aws_s3_bucket_public_access_block.devops553 will be created
  # aws_s3_bucket_server_side_encryption_configuration.devops553 will be created
  # aws_s3_bucket_versioning.devops553 will be created

Plan: 4 to add, 0 to change, 0 to destroy.
```

`(known after apply)` means the value is only known once AWS has created the resource (ARN, domain names, IDs).

### 5. `terraform apply`

Shows the plan again, asks for confirmation, then creates the resources (bucket first, then the three dependent resources in parallel).

```bash
terraform apply
```

```text
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_s3_bucket.devops553: Creating...
aws_s3_bucket.devops553: Creation complete after 3s [id=joe-tf-s3-demo-24bcs10214]
aws_s3_bucket_public_access_block.devops553: Creating...
aws_s3_bucket_versioning.devops553: Creating...
aws_s3_bucket_server_side_encryption_configuration.devops553: Creating...
aws_s3_bucket_public_access_block.devops553: Creation complete after 1s [id=joe-tf-s3-demo-24bcs10214]
aws_s3_bucket_server_side_encryption_configuration.devops553: Creation complete after 1s [id=joe-tf-s3-demo-24bcs10214]
aws_s3_bucket_versioning.devops553: Creation complete after 2s [id=joe-tf-s3-demo-24bcs10214]

Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:

bucket_arn = "arn:aws:s3:::joe-tf-s3-demo-24bcs10214"
bucket_name = "joe-tf-s3-demo-24bcs10214"
bucket_region = "us-east-1"
bucket_regional_domain_name = "joe-tf-s3-demo-24bcs10214.s3.us-east-1.amazonaws.com"
versioning_status = "Enabled"
```

### 6. `terraform show`

Prints the current state in human-readable form (every attribute Terraform knows about each resource).

```bash
terraform show
terraform state list                              # just the resource addresses
terraform state show aws_s3_bucket.devops553      # one resource
```

```text
# aws_s3_bucket.devops553:
resource "aws_s3_bucket" "devops553" {
    arn                         = "arn:aws:s3:::joe-tf-s3-demo-24bcs10214"
    bucket                      = "joe-tf-s3-demo-24bcs10214"
    bucket_domain_name          = "joe-tf-s3-demo-24bcs10214.s3.amazonaws.com"
    bucket_region               = "us-east-1"
    force_destroy               = true
    hosted_zone_id              = "Z3AQBSTGFYJSTF"
    region                      = "us-east-1"
    ...
```

### 7. `terraform output`

```bash
terraform output
terraform output bucket_name
terraform output -raw bucket_name     # without quotes, useful in scripts
terraform output -json                # machine readable
```

```text
bucket_arn = "arn:aws:s3:::joe-tf-s3-demo-24bcs10214"
bucket_name = "joe-tf-s3-demo-24bcs10214"
bucket_region = "us-east-1"
bucket_regional_domain_name = "joe-tf-s3-demo-24bcs10214.s3.us-east-1.amazonaws.com"
versioning_status = "Enabled"
```

### Verify with the AWS CLI

```bash
aws s3 ls
aws s3api get-bucket-versioning   --bucket joe-tf-s3-demo-24bcs10214
aws s3api get-bucket-encryption   --bucket joe-tf-s3-demo-24bcs10214
aws s3api get-public-access-block --bucket joe-tf-s3-demo-24bcs10214
aws s3 cp README.md s3://joe-tf-s3-demo-24bcs10214/
aws s3 ls s3://joe-tf-s3-demo-24bcs10214/
```

```text
{
    "Status": "Enabled"
}
```

### 8. `terraform destroy`

Refreshes the state, shows a destroy plan, asks for confirmation and deletes everything in reverse dependency order (bucket settings first, bucket last).

```bash
terraform plan -destroy   # optional preview
terraform destroy
```

```text
Plan: 0 to add, 0 to change, 4 to destroy.

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

aws_s3_bucket_public_access_block.devops553: Destroying... [id=joe-tf-s3-demo-24bcs10214]
aws_s3_bucket_versioning.devops553: Destroying... [id=joe-tf-s3-demo-24bcs10214]
aws_s3_bucket_server_side_encryption_configuration.devops553: Destroying... [id=joe-tf-s3-demo-24bcs10214]
...
aws_s3_bucket.devops553: Destruction complete after 2s

Destroy complete! Resources: 4 destroyed.
```

Afterwards `terraform state list` is empty and `aws s3 ls s3://joe-tf-s3-demo-24bcs10214/` returns `NoSuchBucket`.

## Command Summary

| Command | What it does | Touches AWS? | Changes state? |
|---|---|---|---|
| `terraform init` | Downloads providers, sets up backend, writes lock file | Registry only | No |
| `terraform fmt` | Formats `.tf` files | No | No |
| `terraform validate` | Checks configuration is syntactically valid and consistent | No | No |
| `terraform plan` | Shows the diff between config and real infrastructure | Reads | No |
| `terraform apply` | Creates / updates / deletes resources to match the config | **Writes** | Yes |
| `terraform show` | Displays state (or a saved plan file) | No | No |
| `terraform output` | Prints output values from state | No | No |
| `terraform destroy` | Deletes all managed resources | **Writes** | Yes |

## Terraform Lifecycle

```text
 write .tf ──► init ──► fmt ──► validate ──► plan ──► apply ──► show / output ──► destroy
                                               ▲          │
                                               └── edit ◄─┘   (change config, plan again)
```

## Notes

* `terraform.tfstate` contains real resource IDs and can contain secrets - it is git-ignored. In teams use a remote backend (S3 with `use_lockfile = true`).
* `.terraform.lock.hcl` **is committed** so everyone uses the same provider version.
* Bucket names are global - change `bucket_name` in `terraform.tfvars` if the name is already taken (`BucketAlreadyExists`).
* Override a variable without editing files: `terraform apply -var="environment=test"`.
