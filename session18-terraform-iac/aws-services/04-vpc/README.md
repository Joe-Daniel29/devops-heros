# 04 - VPC (Virtual Private Cloud) - Networking

## What is VPC?

A **Virtual Private Cloud (VPC)** is your own logically isolated network inside an AWS region. You control its IP address range, subnets, routing, gateways and firewalls - like a traditional data-center network, but software-defined.

* **Regional** - a VPC spans all Availability Zones of one region; each **subnet** lives in exactly one AZ.
* Every account has a **default VPC** per region (`172.31.0.0/16`, a public subnet in every AZ) for quick starts. Production workloads use **custom VPCs**.
* Default quota: 5 VPCs per region (adjustable).

```text
Internet
   │
Internet Gateway (igw)
   │
VPC 10.0.0.0/16  (region us-east-1)
├── us-east-1a
│   ├── Public subnet   10.0.1.0/24   → ALB, NAT Gateway, bastion   (route 0.0.0.0/0 → igw)
│   └── Private subnet  10.0.11.0/24  → EC2 app servers, RDS        (route 0.0.0.0/0 → nat-a)
└── us-east-1b
    ├── Public subnet   10.0.2.0/24   → ALB, NAT Gateway            (route 0.0.0.0/0 → igw)
    └── Private subnet  10.0.12.0/24  → EC2 app servers, RDS        (route 0.0.0.0/0 → nat-b)
```

---

## CIDR

**CIDR (Classless Inter-Domain Routing)** notation describes an IP range as `address/prefix-length`. The prefix length is the number of fixed network bits; the remaining bits are for hosts.

| CIDR | Netmask | Total addresses | Usable in AWS subnet (−5 reserved) |
|---|---|---|---|
| `10.0.0.0/16` | 255.255.0.0 | 65,536 | - (VPC) |
| `10.0.1.0/24` | 255.255.255.0 | 256 | 251 |
| `10.0.1.0/26` | 255.255.255.192 | 64 | 59 |
| `10.0.1.0/28` | 255.255.255.240 | 16 | 11 |

Rules in AWS:

* VPC CIDR size between **/16** (65,536 IPs) and **/28** (16 IPs); you can add secondary CIDRs and an IPv6 /56.
* Use **RFC 1918 private ranges**: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
* Plan non-overlapping ranges if VPCs will be peered or connected to on-prem networks.
* AWS reserves **5 IPs per subnet**: network address (.0), VPC router (.1), DNS (.2), future use (.3), broadcast (last).

---

## Subnets

A **subnet** is a range of IPs inside the VPC, bound to **one AZ**. Resources (EC2, RDS, Lambda ENIs, load balancers) are launched into subnets.

```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "session18-vpc" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "public-a" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "private-a" }
}
```

Spread subnets over **at least two AZs** for high availability.

---

## Route Tables

A **route table** contains rules (**routes**) that decide where network traffic from a subnet is sent.

* Every VPC has a **main route table**; each subnet is associated with exactly one route table (explicitly or the main one).
* Every route table contains the **local route** (VPC CIDR → `local`) which cannot be removed - all subnets in a VPC can reach each other by default.
* Most specific route (longest prefix) wins.

| Public route table | | Private route table | |
|---|---|---|---|
| Destination | Target | Destination | Target |
| `10.0.0.0/16` | local | `10.0.0.0/16` | local |
| `0.0.0.0/0` | `igw-0d9bfbd580efe632e` | `0.0.0.0/0` | `nat-0a1b2c3d4e5f67890` |

```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
```

---

## Internet Gateway

An **Internet Gateway (IGW)** is a horizontally scaled, highly available VPC component that allows communication between the VPC and the internet.

* One IGW per VPC; free of charge.
* Performs **1:1 NAT** between an instance's private IP and its public/Elastic IP.
* A subnet becomes "public" only when its route table has `0.0.0.0/0 → igw-...`.
* Supports IPv4 and IPv6 (for IPv6 outbound-only use an **Egress-only IGW**).

```hcl
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}
```

---

## NAT Gateway

A **NAT Gateway** lets instances in **private subnets** initiate **outbound** connections to the internet (OS updates, external APIs, pulling container images) while **blocking inbound** connections from the internet.

* Created in a **public subnet** with an **Elastic IP**; private route tables point `0.0.0.0/0` to it.
* Managed, scales to 100 Gbps, zonal - create **one per AZ** for HA (avoid cross-AZ dependency).
* Charged per hour **and** per GB processed - a common hidden cost. Use **VPC endpoints** for S3/DynamoDB traffic to avoid NAT charges.
* (Older alternative: self-managed NAT instance.)

```hcl
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "a" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.a.id
  }
}
```

| | Internet Gateway | NAT Gateway |
|---|---|---|
| Direction | Inbound + outbound | Outbound only (initiated from inside) |
| Used by | Public subnets | Private subnets |
| Instance needs public IP? | Yes | No |
| Cost | Free | Hourly + per GB |

---

## Security Groups

**Security groups** are **stateful, instance-level (ENI-level)** firewalls.

* Allow rules only; everything else is denied.
* Return traffic is automatically allowed (stateful).
* Can reference other security groups as sources - ideal for tiered architectures:

```text
Internet ──443──► [alb-sg] ALB ──8080──► [app-sg] EC2 ──5432──► [db-sg] RDS
  app-sg inbound: 8080 from alb-sg
  db-sg  inbound: 5432 from app-sg
```

---

## Network ACLs

**Network ACLs (NACLs)** are **stateless, subnet-level** firewalls.

* Contain numbered rules evaluated **in order, lowest first**; first match wins; final `*` rule denies.
* Support **allow and deny** rules (e.g. block a malicious IP range).
* **Stateless** - return traffic must be explicitly allowed (ephemeral ports `1024-65535`).
* Default NACL allows all inbound and outbound; a newly created custom NACL denies everything.

| Rule # | Type | Port | Source | Action |
|---|---|---|---|---|
| 100 | HTTPS | 443 | 0.0.0.0/0 | ALLOW |
| 110 | Custom TCP | 1024-65535 | 0.0.0.0/0 | ALLOW (return traffic) |
| 120 | SSH | 22 | 198.51.100.0/24 | DENY |
| * | All | All | 0.0.0.0/0 | DENY |

### Security Group vs Network ACL

| Feature | Security Group | Network ACL |
|---|---|---|
| Level | Instance / ENI | Subnet |
| State | **Stateful** | **Stateless** |
| Rules | Allow only | Allow and Deny |
| Evaluation | All rules evaluated together | In number order, first match wins |
| Default (custom) | Deny all in, allow all out | Deny all (custom) / allow all (default NACL) |
| Typical use | Primary access control | Extra subnet-wide guardrail, blocking IPs |

---

## Public vs Private Subnet

| | Public subnet | Private subnet |
|---|---|---|
| Route `0.0.0.0/0` points to | **Internet Gateway** | **NAT Gateway** (or no internet route at all) |
| Instances get public IPs | Usually (`map_public_ip_on_launch = true`) | No |
| Reachable from internet | Yes (if SG/NACL allow) | **No** |
| Can reach internet | Yes, directly | Outbound only via NAT |
| Typical resources | Load balancers, NAT Gateways, bastion hosts | App servers, databases, caches, EKS worker nodes |

> A subnet is not "public" because of a checkbox - it is public **only because of its route to an Internet Gateway**.

---

## Other VPC Features (good to know)

| Feature | Purpose |
|---|---|
| **VPC Endpoints** | Private access to AWS services: Gateway endpoints (S3, DynamoDB - free), Interface endpoints / PrivateLink (most other services) |
| **VPC Peering** | Private routing between two VPCs (non-transitive) |
| **Transit Gateway** | Hub-and-spoke connectivity between many VPCs and on-prem |
| **Site-to-Site VPN / Direct Connect** | Connect on-prem data centers |
| **VPC Flow Logs** | Capture IP traffic metadata to CloudWatch Logs / S3 for troubleshooting and security |

## Quick CLI Reference

```bash
aws ec2 describe-vpcs --query 'Vpcs[].{Id:VpcId,Cidr:CidrBlock,Default:IsDefault}' --output table
aws ec2 describe-subnets --filters Name=vpc-id,Values=vpc-0089cf31bf27821d0 \
  --query 'Subnets[].{Id:SubnetId,Cidr:CidrBlock,AZ:AvailabilityZone,Public:MapPublicIpOnLaunch}'
aws ec2 describe-route-tables --filters Name=vpc-id,Values=vpc-0089cf31bf27821d0
aws ec2 describe-internet-gateways
aws ec2 describe-nat-gateways
aws ec2 describe-network-acls
```
