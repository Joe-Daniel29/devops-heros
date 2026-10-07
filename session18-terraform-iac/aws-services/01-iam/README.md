# 01 - IAM (Identity and Access Management) - Governance

## What is IAM?

**AWS Identity and Access Management (IAM)** is the global AWS service that controls **who** can do **what** on **which** AWS resources, and **under which conditions**.

* **Authentication** - proving who you are (password + MFA, access keys, temporary credentials from a role).
* **Authorization** - deciding whether an authenticated request is allowed (evaluated against policies).

Key facts:

| Property | Value |
|---|---|
| Scope | Global (not tied to a region) |
| Cost | Free (you pay only for the resources the identities use) |
| Default behaviour | **Implicit deny** - nothing is allowed until a policy allows it |
| Root user | Created with the account; has unrestricted access and cannot be limited by IAM policies (only by SCPs in AWS Organizations) |

Every API call to AWS (Console click, CLI command, Terraform apply, SDK call) is signed with credentials and checked by IAM.

```text
  Principal (user / role)          Request                         Resource
  ───────────────────────   ──────────────────────────────   ──────────────────────
  joe-devops        ──►  s3:PutObject  on  arn:aws:s3:::my-bucket/*  ──►  ALLOW / DENY
                                   │
                                   ▼
                     IAM policy evaluation engine
          (identity policies + resource policies + SCPs + boundaries + session policies)
```

---

## Users

An **IAM user** is a long-term identity that represents a **person or an application** inside one AWS account.

* Has a name and an ARN: `arn:aws:iam::210987654321:user/joe-devops`
* Can have **console credentials** (password, optionally MFA) and/or **programmatic credentials** (up to 2 access keys: `AKIA...` + secret).
* Has **no permissions** when created.

```bash
aws iam create-user --user-name joe-devops
aws iam create-login-profile --user-name joe-devops --password 'S0me-Str0ng-P@ss' --password-reset-required
aws iam create-access-key --user-name joe-devops
aws sts get-caller-identity          # who am I?
```

> Modern best practice: humans should sign in through **IAM Identity Center (SSO)** and get temporary credentials; IAM users with long-lived access keys should be the exception (e.g. legacy tools that cannot assume roles).

---

## Groups

An **IAM group** is a collection of users. Policies attached to a group apply to every member.

* A user can be in **up to 10 groups**.
* Groups **cannot be nested** and **cannot be a principal** in a resource policy (you cannot "log in as a group").

| Group | Attached policies | Members |
|---|---|---|
| `Admins` | `AdministratorAccess` | 2 senior engineers |
| `Developers` | `PowerUserAccess`, custom `DenyProdDelete` | developers |
| `ReadOnly` | `ReadOnlyAccess` | auditors, interns |

```bash
aws iam create-group --group-name Developers
aws iam attach-group-policy --group-name Developers --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
aws iam add-user-to-group  --group-name Developers --user-name joe-devops
```

---

## Roles

An **IAM role** is an identity with permissions but **no long-term credentials**. It is **assumed** by a trusted entity, and AWS STS returns **temporary credentials** (access key + secret + session token, valid 15 min - 12 h).

A role has two policies:

1. **Trust policy** - *who* may assume the role.
2. **Permissions policy** - *what* the role may do once assumed.

Who can assume roles:

* AWS services - EC2 (instance profile), Lambda, ECS tasks, EKS pods (IRSA / Pod Identity)
* Users or roles in the same or another AWS account (cross-account access)
* Federated identities - SAML, OIDC (e.g. GitHub Actions OIDC), IAM Identity Center

Example trust policy allowing EC2 to assume the role:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ec2.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

Terraform example:

```hcl
resource "aws_iam_role" "app" {
  name = "app-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_read" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "app" {
  name = "app-ec2-profile"
  role = aws_iam_role.app.name
}
```

---

## Policies

A **policy** is a JSON document that defines permissions. Structure:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadOneBucket",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::joe-tf-s3-demo-24bcs10214",
        "arn:aws:s3:::joe-tf-s3-demo-24bcs10214/*"
      ],
      "Condition": {
        "Bool": { "aws:SecureTransport": "true" }
      }
    }
  ]
}
```

| Element | Meaning |
|---|---|
| `Version` | Policy language version - always `2012-10-17` |
| `Sid` | Optional statement ID |
| `Effect` | `Allow` or `Deny` |
| `Action` | API actions, e.g. `ec2:StartInstances`, wildcards allowed (`s3:Get*`) |
| `Resource` | ARNs the statement applies to |
| `Condition` | Optional - IP range, MFA present, tags, time, TLS, etc. |
| `Principal` | Only in **resource-based** policies (who the policy applies to) |

### Policy types

| Type | Attached to | Notes |
|---|---|---|
| **AWS managed** | users / groups / roles | Created and maintained by AWS (`ReadOnlyAccess`, `AmazonS3FullAccess`) |
| **Customer managed** | users / groups / roles | Created by you, reusable, versioned (up to 5 versions) |
| **Inline** | one identity | Embedded in a single user/group/role; deleted with it |
| **Resource-based** | a resource | S3 bucket policy, SQS queue policy, KMS key policy, role trust policy |
| **Permissions boundary** | user / role | Sets the *maximum* permissions an identity can ever get |
| **SCP** (Organizations) | account / OU | Guardrail for whole accounts; does not grant, only limits |
| **Session policy** | an assumed-role session | Further restricts a temporary session |

---

## Permissions (how a request is evaluated)

```text
1. Is there an explicit DENY in any applicable policy?  ── yes ──► DENY
                     │ no
2. Do SCPs / permission boundaries / session policies allow it?  ── no ──► DENY
                     │ yes
3. Is there an ALLOW in an identity or resource policy?  ── no ──► DENY (implicit)
                     │ yes
                   ALLOW
```

Rules to remember:

* **Explicit Deny always wins.**
* Everything not explicitly allowed is **implicitly denied**.
* For cross-account access **both** sides must allow (identity policy in account A + resource/trust policy in account B).

Testing permissions:

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::210987654321:user/joe-devops \
  --action-names s3:DeleteBucket ec2:RunInstances
```

---

## Least Privilege

**Principle of least privilege:** grant only the permissions required to perform a task - nothing more, for no longer than needed.

How to apply it in practice:

1. Start from **AWS managed job-function policies** only while exploring, then replace them with **customer managed policies** scoped to specific actions and ARNs.
2. Avoid `"Action": "*"` and `"Resource": "*"` together.
3. Use **conditions** (source IP, `aws:MultiFactorAuthPresent`, `aws:RequestedRegion`, resource tags).
4. Use **IAM Access Analyzer** to generate policies from CloudTrail activity and to find unused access.
5. Review **last accessed** information (`aws iam generate-service-last-accessed-details`) and remove unused permissions.
6. Prefer **temporary credentials** (roles) over long-term keys.

| Too broad | Least privilege |
|---|---|
| `AmazonS3FullAccess` for an app that only reads one bucket | `s3:GetObject` on `arn:aws:s3:::app-assets/*` |
| `AdministratorAccess` for the CI pipeline | Role with only the actions Terraform needs, assumable only from the CI OIDC provider |

---

## IAM Best Practices

1. **Lock away the root user** - enable MFA, delete root access keys, use root only for the few tasks that require it.
2. **Enable MFA** for every human identity.
3. **Use IAM Identity Center / federation** for humans; avoid IAM users where possible.
4. **Use roles for workloads** (EC2 instance profiles, Lambda execution roles, IRSA on EKS, GitHub OIDC for CI) - never hard-code access keys.
5. **Rotate** any access keys that must exist; remove unused credentials (credential report: `aws iam generate-credential-report`).
6. **Grant least privilege** and refine with Access Analyzer.
7. **Use groups** to assign permissions to users, not individual attachments.
8. **Strong password policy** (`aws iam update-account-password-policy`).
9. **Use conditions** for extra security (MFA, IP, TLS, region).
10. **Use permission boundaries and SCPs** as guardrails in multi-account setups.
11. **Monitor** with CloudTrail, IAM Access Analyzer and AWS Config rules.
12. **Never commit credentials** to Git (`~/.aws/credentials` stays local; use `git-secrets` / secret scanning).

---

## Common Use Cases

| Use case | IAM building block |
|---|---|
| Team members log in to the console with MFA | Identity Center users / IAM users + groups + MFA |
| EC2 app reads objects from S3 | IAM role + instance profile |
| Lambda writes to DynamoDB | Lambda execution role |
| GitHub Actions deploys with Terraform without stored keys | OIDC identity provider + role with trust on the repo |
| Auditor needs read-only access to another account | Cross-account role with `ReadOnlyAccess` |
| Allow a partner account to upload to one bucket | S3 bucket policy (resource-based) |
| Prevent anyone from leaving approved regions | SCP with `aws:RequestedRegion` condition |
| Delegate IAM admin without privilege escalation | Permissions boundary |

---

## Quick CLI Reference

```bash
aws iam list-users
aws iam list-groups
aws iam list-roles --query 'Roles[].RoleName'
aws iam list-attached-user-policies --user-name joe-devops
aws iam get-policy-version --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess --version-id v1
aws sts assume-role --role-arn arn:aws:iam::210987654321:role/app-ec2-role --role-session-name test
```
