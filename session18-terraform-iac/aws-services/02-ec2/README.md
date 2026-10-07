# 02 - EC2 (Elastic Compute Cloud) - Compute

## What is EC2?

**Amazon EC2** provides resizable virtual servers (**instances**) in the AWS cloud. You choose the operating system, CPU/memory size, storage and network, launch it in minutes, and pay only while it runs.

* **IaaS** - you manage the OS, patches, runtime and application; AWS manages the hardware, hypervisor (Nitro) and data center.
* **Regional / AZ scoped** - an instance lives in one subnet, i.e. one Availability Zone.
* **Pricing models:**

| Model | Description | Typical saving vs On-Demand |
|---|---|---|
| On-Demand | Pay per second, no commitment | - |
| Savings Plans / Reserved Instances | 1 or 3 year commitment | up to ~72% |
| Spot | Spare capacity, can be reclaimed with 2-minute notice | up to ~90% |
| Dedicated Hosts / Instances | Physical isolation, licensing | premium |

```text
Internet
   │
   ▼
Internet Gateway
   │
   ▼
VPC 10.0.0.0/16 ── Public subnet 10.0.1.0/24 (us-east-1a)
   │
   ▼
Security Group  (allow 22 from my IP, 80/443 from anywhere)
   │
   ▼
EC2 instance
   ├── AMI           : Amazon Linux 2023
   ├── Instance type : t3.micro (2 vCPU, 1 GiB RAM)
   ├── Key pair      : joe-key
   ├── Private IP    : 10.0.1.25   Public IP: 3.x.x.x
   └── EBS gp3 root volume (8 GiB)
```

---

## AMI (Amazon Machine Image)

An **AMI** is the template used to launch an instance. It contains:

* a snapshot of the root volume (OS + preinstalled software),
* launch permissions (who can use it),
* block device mapping (which volumes to attach).

| Source | Examples |
|---|---|
| AWS provided | Amazon Linux 2023, Ubuntu 24.04, Windows Server 2025, RHEL |
| AWS Marketplace | Hardened / licensed images (CIS, Bitnami, NGINX Plus) |
| Community | Public AMIs shared by others (verify the publisher!) |
| Custom ("golden") | Built by you with `create-image` or **Packer / EC2 Image Builder** |

AMIs are **regional** (IDs differ per region; copy with `aws ec2 copy-image`).

```bash
# latest Amazon Linux 2023 AMI via SSM public parameter
aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameter.Value' --output text
```

```hcl
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}
```

---

## Instance Types

Instance type = hardware profile. Naming: **`m7g.large`** → family `m`, generation `7`, attribute `g` (Graviton/ARM), size `large`.

| Family | Optimised for | Examples | Use |
|---|---|---|---|
| **T** (burstable) | General, CPU credits | `t3.micro`, `t4g.small` | dev/test, small web apps (Free Tier) |
| **M** | General purpose balanced | `m7i.large`, `m7g.xlarge` | app servers, backends |
| **C** | Compute | `c7i.2xlarge` | batch, CI runners, video encoding |
| **R / X** | Memory | `r7g.4xlarge` | in-memory caches, big databases |
| **I / D** | Storage (local NVMe) | `i4i.large` | NoSQL, data warehousing |
| **P / G / Inf / Trn** | Accelerated (GPU / ML chips) | `g5.xlarge`, `p5.48xlarge` | ML training/inference, graphics |

Sizes double each step: `nano < micro < small < medium < large < xlarge < 2xlarge ...`. Instance type can be changed while the instance is **stopped** (vertical scaling).

---

## Key Pairs

A **key pair** (public + private key) is used for **SSH** login to Linux instances (and to decrypt the Windows admin password).

* AWS stores only the **public key** and injects it into `~/.ssh/authorized_keys` at first boot.
* You download the **private key** (`.pem`) **once** - if it is lost, it cannot be recovered.
* Types: RSA or ED25519.

```bash
aws ec2 create-key-pair --key-name joe-key --key-type ed25519 \
  --query 'KeyMaterial' --output text > joe-key.pem
chmod 400 joe-key.pem
ssh -i joe-key.pem ec2-user@<public-ip>      # ubuntu@ for Ubuntu AMIs
```

> Alternative without open port 22 and without keys: **EC2 Instance Connect** or **SSM Session Manager** (`aws ssm start-session --target i-0abc...`).

---

## Security Groups

A **security group (SG)** is a **stateful virtual firewall** attached to an instance's network interface (ENI).

* Only **allow** rules (no deny rules).
* **Stateful** - if inbound traffic is allowed, the response is automatically allowed out.
* Default: **all inbound denied, all outbound allowed**.
* Sources can be CIDR ranges **or other security groups** (e.g. "allow 5432 only from the app SG").
* Changes take effect immediately; one instance can have up to 5 SGs.

| Direction | Protocol | Port | Source | Purpose |
|---|---|---|---|---|
| Inbound | TCP | 22 | `203.0.113.10/32` (my IP) | SSH |
| Inbound | TCP | 80 / 443 | `0.0.0.0/0` | Web traffic |
| Outbound | All | All | `0.0.0.0/0` | Updates, API calls |

```hcl
resource "aws_security_group" "web" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}
```

---

## EBS (Elastic Block Store)

**EBS** provides network-attached **block storage volumes** for EC2 - like a virtual hard disk.

* Lives in **one AZ** - can attach only to instances in the same AZ.
* Persists independently of the instance (unless `DeleteOnTermination = true`, the default for root volumes).
* **Snapshots** are incremental backups stored in S3 (regional); used to copy volumes across AZs/regions and to build AMIs.
* Encryption with KMS (can be enabled by default per region).

| Volume type | Kind | Max IOPS | Use |
|---|---|---|---|
| `gp3` | General SSD | 16,000 (80,000 on newest) | default for most workloads |
| `gp2` | General SSD (older) | 16,000 (tied to size) | legacy |
| `io2 Block Express` | Provisioned IOPS SSD | 256,000 | critical databases |
| `st1` | Throughput HDD | 500 | big data, logs |
| `sc1` | Cold HDD | 250 | infrequently accessed |

**Instance store** = physically attached disk, very fast but **ephemeral** (data lost on stop/terminate).

```bash
aws ec2 create-volume --availability-zone us-east-1a --size 20 --volume-type gp3
aws ec2 attach-volume --volume-id vol-0abc... --instance-id i-0abc... --device /dev/sdf
aws ec2 create-snapshot --volume-id vol-0abc... --description "before upgrade"
```

---

## Public vs Private IP

| | Private IP | Public IP | Elastic IP |
|---|---|---|---|
| Reachable from | Inside the VPC (and peered / VPN networks) | Internet | Internet |
| Assigned | Always, from the subnet CIDR (e.g. `10.0.1.25`) | If the subnet/launch enables it | Allocated by you, attached to an instance/ENI |
| Changes on stop/start? | **No** - stays for the instance lifetime | **Yes** - new address after stop/start | **No** - static until released |
| Cost | Free | Charged per hour (IPv4) | Charged per hour (IPv4) |

* A public IPv4 is actually **NAT-ed by the Internet Gateway** - the OS only sees the private IP.
* Instances in a **private subnet** have no public IP and reach the internet only through a **NAT Gateway**.
* IPv6 addresses are globally unique and public-routable (control with SGs / egress-only IGW).

---

## Instance Lifecycle

```text
            launch
   AMI ───────────────►  pending ───────► running ◄─────────┐
                                            │  │  │           │ start
                               reboot ◄─────┘  │  └── stop ──► stopping ──► stopped
                             (same host,       │                               │
                              keeps IPs)        │ terminate                     │ terminate
                                                ▼                               ▼
                                          shutting-down ─────────────────► terminated
                                                                  (gone, visible ~1 hour)
   running ── hibernate ──► stopping ──► stopped   (RAM saved to encrypted EBS root)
```

| State | Billing for compute | Notes |
|---|---|---|
| `pending` | No | Booting, being placed on a host |
| `running` | **Yes** | Billed per second (Linux) |
| `stopping` / `stopped` | No (EBS still billed) | Public IP released; can change instance type |
| `shutting-down` / `terminated` | No | Root EBS deleted by default; cannot be restarted |

**User data** scripts run on first boot (cloud-init) - commonly used to install software:

```bash
#!/bin/bash
dnf install -y nginx
systemctl enable --now nginx
```

---

## Common Use Cases

| Use case | Typical setup |
|---|---|
| Web / application servers | Auto Scaling Group of `t3`/`m7` instances behind an Application Load Balancer |
| Self-managed Kubernetes / Docker hosts | EKS managed node groups or plain EC2 with Docker |
| CI/CD build runners | `c7` Spot instances (GitHub/Jenkins runners) |
| Bastion / jump host | Small instance in public subnet (or replace with SSM Session Manager) |
| Batch & HPC | `c`/`hpc` instances with placement groups, AWS Batch |
| Machine learning | `g5` / `p5` GPU instances |
| Lift-and-shift of on-prem VMs | AWS Application Migration Service → EC2 |

---

## Terraform Example (complete)

```hcl
resource "aws_instance" "web" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = "joe-key"
  associate_public_ip_address = true
  user_data                   = file("${path.module}/user-data.sh")

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "web-server" }
}

output "public_ip" { value = aws_instance.web.public_ip }
```

## Quick CLI Reference

```bash
aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]' --output table
aws ec2 run-instances --image-id ami-0abc... --instance-type t3.micro --key-name joe-key --subnet-id subnet-0abc...
aws ec2 stop-instances --instance-ids i-0abc...
aws ec2 start-instances --instance-ids i-0abc...
aws ec2 terminate-instances --instance-ids i-0abc...
```
