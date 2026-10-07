# 03 - S3 (Simple Storage Service) - Storage

## What is S3?

**Amazon S3** is a fully managed **object storage** service. You store any amount of data as **objects** inside **buckets** and access it over HTTPS through the S3 API.

| Property | Value |
|---|---|
| Storage model | Object storage (key → data + metadata), not a file system or block device |
| Durability | **99.999999999 % (11 nines)** - data is stored redundantly across ≥ 3 AZs (except One Zone classes) |
| Availability | 99.99 % (S3 Standard) |
| Max object size | 5 TB (single PUT up to 5 GB; use **multipart upload** above ~100 MB) |
| Capacity | Unlimited |
| Consistency | Strong read-after-write consistency for all operations |
| Pricing | Per GB-month stored + requests + data transfer out |

```text
s3://joe-tf-s3-demo-24bcs10214/reports/2026/september.csv
     └──────────── bucket ─────────┘└──────── object key ──────┘
```

---

## Buckets

A **bucket** is the top-level container for objects.

* Bucket names are **globally unique** across all AWS accounts (DNS-compatible: 3-63 chars, lowercase, numbers, hyphens, dots).
* A bucket is created in **one region** (data never leaves it unless you replicate it).
* Default soft limit: 10,000 buckets per account.
* New buckets are **private by default**: Block Public Access ON, ACLs disabled (Object Ownership = *Bucket owner enforced*), SSE-S3 encryption ON.
* Bucket types: **general purpose** (classic), **directory buckets** (S3 Express One Zone, single-digit ms latency), **table buckets** (Apache Iceberg), **vector buckets**.

```bash
aws s3 mb s3://joe-tf-s3-demo-24bcs10214 --region us-east-1
aws s3 ls
aws s3 rb s3://joe-tf-s3-demo-24bcs10214 --force   # delete bucket and its contents
```

Terraform (as used in this session's `terraform-s3-demo`):

```hcl
resource "aws_s3_bucket" "devops553" {
  bucket        = var.bucket_name
  force_destroy = true
}
```

---

## Objects

An **object** consists of:

| Part | Description |
|---|---|
| **Key** | Full name inside the bucket, e.g. `images/logo.png` (the "/" is just part of the name - S3 has a flat namespace; folders are a console illusion via prefixes) |
| **Value** | The data (0 bytes - 5 TB) |
| **Version ID** | Present when versioning is enabled |
| **Metadata** | System (`Content-Type`, `Last-Modified`, `ETag`) and user-defined (`x-amz-meta-*`) |
| **Tags** | Up to 10 key-value pairs (used for lifecycle, access control, cost) |

```bash
aws s3 cp README.md s3://my-bucket/docs/README.md
aws s3 ls s3://my-bucket/docs/
aws s3 sync ./site s3://my-bucket/site --delete
aws s3api head-object --bucket my-bucket --key docs/README.md
aws s3 presign s3://my-bucket/docs/README.md --expires-in 3600   # temporary download URL
```

---

## Storage Classes

| Storage class | Designed for | AZs | Min. duration | Retrieval |
|---|---|---|---|---|
| **S3 Standard** | Frequently accessed data | ≥ 3 | - | ms, no fee |
| **S3 Intelligent-Tiering** | Unknown / changing access patterns; moves objects automatically | ≥ 3 | - | ms (archive tiers optional) |
| **S3 Standard-IA** | Infrequent access, needs fast retrieval | ≥ 3 | 30 days | ms, per-GB fee |
| **S3 One Zone-IA** | Infrequent, re-creatable data | 1 | 30 days | ms, per-GB fee |
| **S3 Express One Zone** | Ultra-low latency (directory buckets) | 1 | - | single-digit ms |
| **S3 Glacier Instant Retrieval** | Archive accessed ~once a quarter | ≥ 3 | 90 days | ms |
| **S3 Glacier Flexible Retrieval** | Archive, minutes-hours retrieval | ≥ 3 | 90 days | 1-5 min (expedited) to 5-12 h |
| **S3 Glacier Deep Archive** | Long-term retention (compliance, 7-10 years) | ≥ 3 | 180 days | 12-48 h |

```bash
aws s3 cp backup.tar.gz s3://my-bucket/ --storage-class GLACIER_IR
```

---

## Versioning

**Versioning** keeps **every version** of every object in the bucket.

* States: **Unversioned** (default) → **Enabled** → **Suspended** (can never go back to unversioned).
* Overwriting an object creates a new version; the old one is kept.
* Deleting an object only adds a **delete marker** - the previous versions can still be restored.
* Protects against accidental overwrite/delete and is **required** for replication and Object Lock.
* Each version is billed - combine with lifecycle rules to expire old versions.
* **MFA Delete** (root only, via CLI) can require MFA to permanently delete versions.

```bash
aws s3api put-bucket-versioning --bucket my-bucket --versioning-configuration Status=Enabled
aws s3api get-bucket-versioning --bucket my-bucket
aws s3api list-object-versions --bucket my-bucket --prefix docs/README.md
```

```hcl
resource "aws_s3_bucket_versioning" "devops553" {
  bucket = aws_s3_bucket.devops553.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

---

## Lifecycle Policies

**Lifecycle rules** automatically **transition** objects to cheaper classes or **expire** (delete) them after a period. Rules can be filtered by prefix, tags or object size.

```text
Day 0           Day 30             Day 90                 Day 365
S3 Standard ──► Standard-IA ──► Glacier Flexible ──►  expire (delete)
noncurrent versions: delete 30 days after becoming noncurrent
incomplete multipart uploads: abort after 7 days
```

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.devops553.id

  rule {
    id     = "logs-retention"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
```

---

## Encryption

| Where | Option | Key management |
|---|---|---|
| **In transit** | HTTPS/TLS (enforce with `aws:SecureTransport` in a bucket policy) | - |
| **At rest (server side)** | **SSE-S3** (`AES256`) - **default for all new objects since Jan 2023** | AWS-managed keys |
| | **SSE-KMS** (`aws:kms`) | AWS KMS keys - audit in CloudTrail, key policies, rotation; use **S3 Bucket Keys** to cut KMS cost |
| | **DSSE-KMS** | Dual-layer encryption with KMS (compliance) |
| | **SSE-C** | Customer provides the key on every request |
| **Client side** | Encrypt before upload (AWS Encryption SDK) | Fully managed by you |

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "devops553" {
  bucket = aws_s3_bucket.devops553.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"          # or "aws:kms" + kms_master_key_id
    }
    bucket_key_enabled = true
  }
}
```

```bash
aws s3api get-bucket-encryption --bucket my-bucket
```

---

## Bucket Policies

A **bucket policy** is a **resource-based IAM policy** attached to a bucket (JSON, max 20 KB). It contains a `Principal` and can grant access to other accounts, services or (if Block Public Access allows) the public.

Example - enforce TLS and allow a CloudFront distribution to read objects:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::joe-tf-s3-demo-24bcs10214",
        "arn:aws:s3:::joe-tf-s3-demo-24bcs10214/*"
      ],
      "Condition": { "Bool": { "aws:SecureTransport": "false" } }
    },
    {
      "Sid": "AllowCloudFrontRead",
      "Effect": "Allow",
      "Principal": { "Service": "cloudfront.amazonaws.com" },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::joe-tf-s3-demo-24bcs10214/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::210987654321:distribution/E2EXAMPLE123"
        }
      }
    }
  ]
}
```

Related access controls:

| Control | Purpose |
|---|---|
| **Block Public Access** (account + bucket level) | Overrides any policy/ACL that would make data public - keep ON unless hosting a public site |
| **Object Ownership** | `BucketOwnerEnforced` disables ACLs (recommended) |
| **IAM identity policies** | What users/roles in your account may do |
| **Access Points** | Named endpoints with their own policies for different apps/teams |
| **Pre-signed URLs** | Time-limited access to a single object |

```hcl
resource "aws_s3_bucket_public_access_block" "devops553" {
  bucket                  = aws_s3_bucket.devops553.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

---

## Common Use Cases

| Use case | Features used |
|---|---|
| Static website hosting (React/HTML) | Bucket + CloudFront + OAC bucket policy |
| Backups and disaster recovery | Versioning, lifecycle to Glacier, Cross-Region Replication |
| Data lake / analytics | Athena, Glue, EMR, S3 Tables (Iceberg) |
| Log storage (CloudTrail, ALB, VPC Flow Logs) | Lifecycle expiration, Object Lock for compliance |
| **Terraform remote state** | Versioned, encrypted bucket + `use_lockfile = true` for state locking |
| Media storage and distribution | Multipart upload, pre-signed URLs, CloudFront |
| Artifact repository for CI/CD | Build outputs, Lambda deployment packages |
| ML datasets and model artifacts | SageMaker, Intelligent-Tiering |

Terraform remote backend example:

```hcl
terraform {
  backend "s3" {
    bucket       = "joe-terraform-state"
    key          = "session18/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```
