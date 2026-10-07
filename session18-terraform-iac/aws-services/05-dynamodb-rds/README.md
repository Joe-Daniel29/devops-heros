# 05 - DynamoDB & RDS - Databases

AWS offers purpose-built databases. The two most common are:

| | **Amazon DynamoDB** | **Amazon RDS** |
|---|---|---|
| Category | NoSQL key-value / document | Relational (SQL) |
| Management | Fully managed, **serverless** (no instances) | Managed DB **instances** (you choose size) |
| Schema | Schemaless (only the key is defined) | Fixed schema (tables, columns, types, constraints) |
| Query language | API (`GetItem`, `Query`, `Scan`) / PartiQL | SQL with joins, transactions, aggregations |
| Scaling | Horizontal, virtually unlimited, automatic | Mostly vertical (bigger instance) + read replicas |
| Latency | Single-digit milliseconds at any scale | Milliseconds, depends on query and instance size |
| Best for | Known access patterns, massive scale, spiky traffic | Complex queries, relationships, existing SQL apps |

---

# Part A - Amazon DynamoDB

## NoSQL

**DynamoDB** is a fully managed, serverless **NoSQL** database that delivers consistent single-digit-millisecond performance at any scale.

* **NoSQL** = "not only SQL": no fixed schema, no joins, data modelled around **access patterns** instead of normalisation.
* Data is replicated across **3 AZs** automatically; optional **Global Tables** replicate across regions (multi-active).
* **Capacity modes:**
  * **On-demand** - pay per request, scales instantly (default, good for unknown traffic).
  * **Provisioned** - set Read/Write Capacity Units (RCU/WCU), optionally with auto scaling (cheaper for steady traffic).
* **Consistency:** eventually consistent reads by default; strongly consistent reads optional; ACID **transactions** (`TransactWriteItems`).
* Features: TTL (auto-expire items), DynamoDB Streams (change data capture → Lambda), Point-in-Time Recovery (35 days), on-demand backups, encryption at rest (always on), DAX in-memory cache.

## Tables

A **table** is a collection of items. When creating a table you define **only the primary key** (and optionally secondary indexes) - every other attribute is free-form.

```bash
aws dynamodb create-table \
  --table-name Orders \
  --attribute-definitions AttributeName=CustomerId,AttributeType=S AttributeName=OrderDate,AttributeType=S \
  --key-schema AttributeName=CustomerId,KeyType=HASH AttributeName=OrderDate,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

```hcl
resource "aws_dynamodb_table" "orders" {
  name         = "Orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "CustomerId"
  range_key    = "OrderDate"

  attribute {
    name = "CustomerId"
    type = "S"
  }

  attribute {
    name = "OrderDate"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  ttl {
    attribute_name = "ExpiresAt"
    enabled        = true
  }

  tags = { Project = "Session18" }
}
```

## Items

An **item** is a single record in a table (like a row), identified uniquely by its primary key. Maximum item size is **400 KB**. Items in the same table can have **different attributes**.

```json
{ "CustomerId": "C#1001", "OrderDate": "2026-09-29T11:20:00Z", "Total": 1499, "Status": "SHIPPED" }
{ "CustomerId": "C#1001", "OrderDate": "2026-09-30T08:05:12Z", "Total": 299,  "Coupon": "FEST10", "Items": ["book", "pen"] }
```

```bash
aws dynamodb put-item --table-name Orders \
  --item '{"CustomerId":{"S":"C#1001"},"OrderDate":{"S":"2026-09-29T11:20:00Z"},"Total":{"N":"1499"}}'
aws dynamodb get-item --table-name Orders \
  --key '{"CustomerId":{"S":"C#1001"},"OrderDate":{"S":"2026-09-29T11:20:00Z"}}'
```

## Attributes

An **attribute** is a name-value pair inside an item (like a column, but per item).

| Type | Code | Example |
|---|---|---|
| String | `S` | `"SHIPPED"` |
| Number | `N` | `1499` |
| Binary | `B` | base64 data |
| Boolean | `BOOL` | `true` |
| Null | `NULL` | `true` |
| List | `L` | `["book", "pen"]` |
| Map | `M` | `{"city": "Bhopal", "pin": "462001"}` |
| String / Number / Binary Set | `SS` / `NS` / `BS` | `["red", "blue"]` |

Only the key attributes must be declared in the table definition.

## Partition Key

The **partition key** (a.k.a. **hash key**) is required in every table.

* DynamoDB hashes its value to decide **which physical partition** stores the item.
* If the table has **only** a partition key, the value must be **unique** per item (simple primary key).
* Choose a **high-cardinality** key with evenly spread traffic (`UserId`, `OrderId`) to avoid **hot partitions**; low-cardinality keys like `Status` or `Country` are bad choices.

## Sort Key

The **sort key** (a.k.a. **range key**) is optional and, together with the partition key, forms a **composite primary key**.

* Many items can share the same partition key; they are stored together, **sorted by the sort key**.
* Enables efficient range queries: `begins_with`, `between`, `<`, `>`.

```bash
# all orders of one customer in September 2026, newest first
aws dynamodb query --table-name Orders \
  --key-condition-expression "CustomerId = :c AND begins_with(OrderDate, :m)" \
  --expression-attribute-values '{":c":{"S":"C#1001"},":m":{"S":"2026-09"}}' \
  --no-scan-index-forward
```

**Secondary indexes** allow other access patterns:

| Index | Keys | Notes |
|---|---|---|
| **GSI** (Global Secondary Index) | Any partition + sort key | Created any time, own capacity, eventually consistent |
| **LSI** (Local Secondary Index) | Same partition key, different sort key | Only at table creation, strongly consistent option |

> `Query` uses the key and is efficient; `Scan` reads the whole table and should be avoided on large tables.

## DynamoDB Use Cases

* User profiles, sessions and shopping carts for web/mobile apps
* Gaming leaderboards and player state
* IoT and time-series telemetry (with TTL to expire old data)
* Serverless backends: API Gateway + Lambda + DynamoDB
* Event-driven systems with DynamoDB Streams
* Metadata store / idempotency keys / feature flags
* (Historically) Terraform state locking table - now replaced by S3 native locking (`use_lockfile = true`)

---

# Part B - Amazon RDS

## Relational Database

**Amazon RDS (Relational Database Service)** is a managed service to set up, operate and scale **relational (SQL) databases**.

A relational database stores data in **tables** of rows and columns with a fixed **schema**, links tables with **primary/foreign keys**, and guarantees **ACID** transactions.

```sql
CREATE TABLE customers (id SERIAL PRIMARY KEY, name TEXT NOT NULL, email TEXT UNIQUE);
CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  customer_id INT REFERENCES customers(id),
  total NUMERIC(10,2),
  created_at TIMESTAMPTZ DEFAULT now()
);
SELECT c.name, SUM(o.total) FROM customers c JOIN orders o ON o.customer_id = c.id GROUP BY c.name;
```

What RDS manages for you vs. what you still do:

| AWS manages | You manage |
|---|---|
| Hardware, OS, DB engine installation and patching | Schema, indexes, queries, query tuning |
| Automated backups and point-in-time restore | Choosing instance class / storage |
| Multi-AZ failover, replication | Users, grants, parameter groups |
| Monitoring (CloudWatch, Performance Insights) | Network design (subnets, security groups) |

## Supported Engines

| Engine | Notes |
|---|---|
| **Amazon Aurora (MySQL- / PostgreSQL-compatible)** | AWS cloud-native engine; storage auto-grows to 128 TiB, 6 copies over 3 AZs, up to 15 low-lag replicas, Aurora Serverless v2 |
| **PostgreSQL** | Open source, rich features (JSONB, extensions like PostGIS, pgvector) |
| **MySQL** | Most popular open-source DB |
| **MariaDB** | Community fork of MySQL |
| **Oracle** | BYOL or license-included |
| **Microsoft SQL Server** | Express, Web, Standard, Enterprise editions |
| **IBM Db2** | Standard / Advanced editions |

**RDS Custom** (Oracle, SQL Server) gives OS-level access for apps that need it.

## DB Instances

A **DB instance** is an isolated database environment in the cloud - the basic building block of RDS. It has:

* **Instance class** - compute and memory, e.g. `db.t4g.micro` (burstable, Free Tier), `db.m7g.large` (general), `db.r7g.xlarge` (memory optimised).
* **Storage** - `gp3` (default), `io2` (provisioned IOPS); **storage autoscaling** can grow it automatically.
* **Endpoint** - DNS name to connect, e.g. `mydb.c1a2b3c4d5e6.us-east-1.rds.amazonaws.com:5432`.
* **DB subnet group** - the (private) subnets in ≥ 2 AZs where the instance may run.
* **Parameter group / option group** - engine configuration.

```hcl
resource "aws_db_subnet_group" "main" {
  name       = "session18-db-subnets"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_db_instance" "postgres" {
  identifier                  = "session18-postgres"
  engine                      = "postgres"
  engine_version              = "17"
  instance_class              = "db.t4g.micro"
  allocated_storage           = 20
  max_allocated_storage       = 100
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = "appdb"
  username                    = "appadmin"
  manage_master_user_password = true          # password stored in Secrets Manager
  db_subnet_group_name        = aws_db_subnet_group.main.name
  vpc_security_group_ids      = [aws_security_group.db.id]
  multi_az                    = true
  backup_retention_period     = 7
  deletion_protection         = true
  skip_final_snapshot         = false
  final_snapshot_identifier   = "session18-postgres-final"
}
```

## Security

| Layer | How |
|---|---|
| **Network isolation** | Place DB in **private subnets**, `publicly_accessible = false` |
| **Firewall** | Security group allows the DB port (3306/5432/1433) **only from the app security group** |
| **Authentication** | Master user + DB users; **IAM database authentication** (tokens instead of passwords) for MySQL/PostgreSQL; Kerberos/AD for SQL Server & Oracle |
| **Secrets** | `manage_master_user_password` → password stored and rotated in **AWS Secrets Manager** |
| **Encryption at rest** | KMS encryption of storage, backups, snapshots and replicas (must be chosen at creation) |
| **Encryption in transit** | SSL/TLS connections (`rds.force_ssl = 1` for PostgreSQL) |
| **Access control** | IAM policies for who can manage RDS (`rds:*` actions) |
| **Auditing** | CloudTrail (API calls), engine audit logs to CloudWatch Logs, Database Activity Streams |

## Backups

* **Automated backups** - daily snapshot during the backup window + transaction logs every 5 minutes → **point-in-time restore (PITR)** to any second within the retention period (**1-35 days**, default 7).
* **Manual snapshots** - user-initiated, kept until you delete them; can be **copied across regions/accounts** and shared.
* **Restore always creates a new DB instance** (new endpoint).
* **AWS Backup** can centrally manage RDS backup plans.

```bash
aws rds create-db-snapshot --db-instance-identifier session18-postgres --db-snapshot-identifier pre-release-snap
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier session18-postgres \
  --target-db-instance-identifier session18-postgres-restored \
  --restore-time 2026-09-29T10:30:00Z
```

## Multi-AZ

**Multi-AZ** provides **high availability** and durability:

```text
           Application ──► DB endpoint (DNS)
                               │
          us-east-1a           │             us-east-1b
     ┌──────────────────┐  synchronous  ┌──────────────────┐
     │ Primary instance │ ────────────► │ Standby instance │
     └──────────────────┘  replication  └──────────────────┘
       on failure: DNS endpoint flips to the standby (~60-120 s)
```

* **Synchronous** replication to a standby in another AZ.
* **Automatic failover** on instance/AZ failure, OS patching, or instance class change - the endpoint stays the same.
* The classic standby **does not serve reads**.
* **Multi-AZ DB cluster** (MySQL/PostgreSQL): 1 writer + 2 **readable** standbys, failover typically < 35 s.
* Used for **HA**, not for read scaling.

## Read Replicas

**Read replicas** are copies of the primary used to **scale read traffic**.

| | Multi-AZ standby | Read replica |
|---|---|---|
| Purpose | High availability | Read scalability |
| Replication | Synchronous | **Asynchronous** (replica lag possible) |
| Readable | No (classic) | **Yes** - own endpoint |
| Location | Another AZ, same region | Same AZ, other AZ, or **another region** |
| Count | 1 standby | Up to 15 (Aurora / MySQL / PostgreSQL) |
| Promotion | Automatic failover | Manual **promotion** to a standalone DB (DR) |

```bash
aws rds create-db-instance-read-replica \
  --db-instance-identifier session18-postgres-replica-1 \
  --source-db-instance-identifier session18-postgres
```

## RDS Use Cases

* Traditional web and mobile application backends (e-commerce, CMS, ERP, CRM)
* Applications needing **joins, complex queries, reporting** and strong consistency
* Financial / transactional systems requiring ACID guarantees
* Migrating existing on-prem MySQL, PostgreSQL, Oracle or SQL Server databases (with **AWS DMS**)
* SaaS products with relational multi-tenant schemas
* Read-heavy apps scaling with read replicas; global apps with cross-region replicas for DR

---

## Choosing Between DynamoDB and RDS

```text
Do you need joins, ad-hoc SQL queries or an existing relational schema?
   ├── yes ──► RDS / Aurora
   └── no
        └── Are access patterns known and do you need massive scale / serverless / ms latency?
               ├── yes ──► DynamoDB
               └── unsure ──► start with RDS (PostgreSQL) - flexible querying
```
