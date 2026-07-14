# Architecture Documentation

## System Overview

StartupHub Infrastructure implements a production-grade, multi-tier architecture on AWS using Infrastructure as Code principles. The system is designed for high availability, security, and automated operations.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                    │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        AWS WAF v2 WebACL                                │
│  ┌──────────────┬──────────────┬──────────────┬──────────────┐         │
│  │ Rate Limit   │ SQL Injection│ XSS Filter   │ IP Reputation│         │
│  │ (2000/5min)  │ Protection   │              │              │         │
│  └──────────────┴──────────────┴──────────────┴──────────────┘         │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    APPLICATION LOAD BALANCER                             │
│                       (Public Subnets x2)                                │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Listener: HTTP (80) → Target Group (3000)                       │  │
│  │  Health Check: / (200)                                           │  │
│  │  Cross-Zone Load Balancing: Enabled                              │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
              ┌────────────────┴────────────────┐
              │                                 │
              ▼                                 ▼
┌─────────────────────────┐       ┌─────────────────────────┐
│   Target Group (3000)   │       │   Target Group (3000)   │
│   Private Subnet 1      │       │   Private Subnet 2      │
└────────────┬────────────┘       └────────────┬────────────┘
             │                                 │
             ▼                                 ▼
┌─────────────────────────┐       ┌─────────────────────────┐
│    EC2 Instance 1       │       │    EC2 Instance 2       │
│  ┌───────────────────┐  │       │  ┌───────────────────┐  │
│  │  Docker Runtime   │  │       │  │  Docker Runtime   │  │
│  │  ┌─────────────┐  │  │       │  │  ┌─────────────┐  │  │
│  │  │  Container  │  │  │       │  │  │  Container  │  │  │
│  │  │  (Node.js)  │  │  │       │  │  │  (Node.js)  │  │  │
│  │  │  Port 3000  │  │  │       │  │  │  Port 3000  │  │  │
│  │  └──────┬──────┘  │  │       │  │  └──────┬──────┘  │  │
│  │         │         │  │       │  │         │         │  │
│  │  CloudWatch Agent │  │       │  │  CloudWatch Agent │  │
│  └─────────┼─────────┘  │       │  └─────────┼─────────┘  │
└────────────┼────────────┘       └────────────┼────────────┘
             │                                 │
             └────────────────┬────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
┌──────────────────┐ ┌──────────────┐ ┌──────────────────┐
│ Amazon ECR       │ │ AWS Secrets  │ │ Amazon RDS       │
│ (Container       │ │ Manager      │ │ PostgreSQL       │
│  Registry)       │ │ (DB Creds)   │ │ (Private DB      │
│                  │ │              │ │  Subnets)        │
└──────────────────┘ └──────────────┘ └──────────────────┘
```

## Network Architecture

### VPC Design

```
┌─────────────────────────────────────────────────────────────────┐
│                    VPC: 10.0.0.0/16                              │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  PUBLIC SUBNETS (ALB)                                   │   │
│  │  ┌──────────────────────┐  ┌──────────────────────┐    │   │
│  │  │ 10.0.1.0/24 (AZ-1a)  │  │ 10.0.2.0/24 (AZ-1b)  │    │   │
│  │  │ Application Load     │  │ Application Load     │    │   │
│  │  │ Balancer             │  │ Balancer             │    │   │
│  │  └──────────────────────┘  └──────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  PRIVATE APPLICATION SUBNETS (EC2)                      │   │
│  │  ┌──────────────────────┐  ┌──────────────────────┐    │   │
│  │  │ 10.0.11.0/24 (AZ-1a) │  │ 10.0.12.0/24 (AZ-1b) │    │   │
│  │  │ EC2 Instance 1       │  │ EC2 Instance 2       │    │   │
│  │  │ Docker Container     │  │ Docker Container     │    │   │
│  │  └──────────────────────┘  └──────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  PRIVATE DATABASE SUBNETS (RDS)                         │   │
│  │  ┌──────────────────────┐  ┌──────────────────────┐    │   │
│  │  │ 10.0.21.0/24 (AZ-1a) │  │ 10.0.22.0/24 (AZ-1b) │    │   │
│  │  │ RDS Primary          │  │ RDS Standby          │    │   │
│  │  └──────────────────────┘  └──────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────┐                    ┌──────────────────┐   │
│  │ Internet Gateway │                    │   NAT Gateway    │   │
│  │   (Public)       │                    │  (Private →      │   │
│  │                  │                    │   Public)        │   │
│  └──────────────────┘                    └──────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Traffic Flow

```
Inbound Traffic:
Internet → WAF → ALB (80) → Target Group (3000) → EC2 → Docker Container

Outbound Traffic:
Docker Container → EC2 → NAT Gateway → Internet
                                        ↓
                              ECR (pull image)
                              AWS APIs (CloudWatch, Secrets Manager)

Database Traffic:
Docker Container → EC2 → RDS PostgreSQL (5432)
```

## Security Architecture

### Defense in Depth

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: Network Security                                   │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • VPC with private subnets                           │ │
│  │ • Security Groups (stateful firewall)                │ │
│  │ • Network ACLs (stateless firewall)                  │ │
│  │ • NAT Gateway for outbound traffic                   │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: Web Application Firewall                           │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • SQL Injection protection                           │ │
│  │ • XSS protection                                     │ │
│  │ • Rate limiting (DDoS protection)                    │ │
│  │ • IP reputation filtering                            │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: Identity & Access                                  │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • IAM Roles (no hardcoded credentials)               │ │
│  │ • Least privilege access                             │ │
│  │ • OIDC authentication for CI/CD                      │ │
│  │ • AWS Secrets Manager for DB credentials             │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Layer 4: Data Security                                      │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • RDS encryption at rest                             │ │
│  │ • EBS encryption at rest                             │ │
│  │ • TLS in transit (HTTPS - future)                    │ │
│  │ • Secrets Manager encryption                         │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Layer 5: Monitoring & Observability                         │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • CloudWatch Logs (30-day retention)                 │ │
│  │ • CloudWatch Metrics (custom + AWS)                  │ │
│  │ • CloudWatch Alarms with SNS notifications           │ │
│  │ • CloudWatch Dashboard (8 widgets)                   │ │
│  │ • WAF metrics and logging                            │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Security Groups

```
ALB Security Group:
┌──────────────────────────────────────────────────────┐
│ Inbound:                                             │
│   • Port 80 (HTTP) from 0.0.0.0/0                   │
│   • Port 443 (HTTPS) from 0.0.0.0/0 (future)        │
│                                                      │
│ Outbound:                                            │
│   • All traffic to EC2 Security Group               │
└──────────────────────────────────────────────────────┘

EC2 Security Group:
┌──────────────────────────────────────────────────────┐
│ Inbound:                                             │
│   • Port 3000 from ALB Security Group only          │
│                                                      │
│ Outbound:                                            │
│   • All traffic to RDS Security Group               │
│   • All traffic to Internet (for ECR, AWS APIs)     │
└──────────────────────────────────────────────────────┘

RDS Security Group:
┌──────────────────────────────────────────────────────┐
│ Inbound:                                             │
│   • Port 5432 from EC2 Security Group only          │
│                                                      │
│ Outbound:                                            │
│   • None (database doesn't initiate connections)    │
└──────────────────────────────────────────────────────┘
```

## Compute Architecture

### EC2 Instance Lifecycle

```
1. ASG Launches Instance
   ↓
2. EC2 Boots Ubuntu 22.04
   ↓
3. User Data Script Executes
   │
   ├─→ Install Docker runtime
   ├─→ Install AWS CLI v2
   ├─→ Install CloudWatch Agent
   ├─→ Authenticate to ECR (IAM role)
   ├─→ Pull Docker image from ECR
   ├─→ Fetch DB credentials from Secrets Manager
   └─→ Start Docker container
   ↓
4. Container Starts
   │
   ├─→ Node.js Express app
   ├─→ Connects to PostgreSQL RDS
   ├─→ Listens on port 3000
   └─→ CloudWatch Agent streams metrics/logs
   ↓
5. Health Check Passes
   │
   └─→ ALB registers instance as healthy
```

### Docker Container Architecture

```
┌─────────────────────────────────────────────────┐
│  Docker Container                               │
│  ┌───────────────────────────────────────────┐ │
│  │  Node.js 18 (Alpine)                      │ │
│  │  ┌─────────────────────────────────────┐ │ │
│  │  │  Express.js Application             │ │ │
│  │  │  ┌───────────────────────────────┐ │ │ │
│  │  │  │  REST API Endpoints           │ │ │ │
│  │  │  │  • GET / (health check)       │ │ │ │
│  │  │  │  • GET /api/tasks             │ │ │ │
│  │  │  │  • POST /api/tasks            │ │ │ │
│  │  │  │  • DELETE /api/tasks/:id      │ │ │ │
│  │  │  └───────────────────────────────┘ │ │ │
│  │  │                                     │ │ │
│  │  │  ┌───────────────────────────────┐ │ │ │
│  │  │  │  PostgreSQL Client            │ │ │ │
│  │  │  │  • Connection pooling         │ │ │ │
│  │  │  │  • SSL/TLS connection         │ │ │ │
│  │  │  │  • Prepared statements        │ │ │ │
│  │  │  └───────────────────────────────┘ │ │ │
│  │  └─────────────────────────────────────┘ │ │
│  │                                           │ │
│  │  Environment Variables:                   │ │
│  │  • DB_HOST (RDS endpoint)                │ │
│  │  • DB_PORT (5432)                        │ │
│  │  • DB_NAME (startuphub)                  │ │
│  │  • DB_USER (startupadmin)                │ │
│  │  • DB_PASSWORD (from Secrets Manager)    │ │
│  │  • PORT (3000)                           │ │
│  └───────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

## Data Architecture

### Database Schema

```
┌─────────────────────────────────────────┐
│  Database: startuphub                   │
│  Engine: PostgreSQL 16                  │
│  Instance: db.t3.micro                  │
│  Storage: 20 GB (gp3, encrypted)        │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  Table: tasks                           │
├─────────────────────────────────────────┤
│  id           SERIAL PRIMARY KEY        │
│  title        VARCHAR(255) NOT NULL     │
│  description  TEXT                      │
│  status       VARCHAR(50) DEFAULT       │
│               'pending'                 │
│  created_at   TIMESTAMP DEFAULT NOW()   │
│  updated_at   TIMESTAMP DEFAULT NOW()   │
└─────────────────────────────────────────┘

Indexes:
• PRIMARY KEY (id)
• idx_tasks_status (status)
• idx_tasks_created_at (created_at DESC)
```

### Data Flow

```
User Request → ALB → EC2 → Docker Container
                                ↓
                        Express.js Router
                                ↓
                        Business Logic Layer
                                ↓
                        Database Query Builder
                                ↓
                        PostgreSQL Client
                                ↓
                        RDS PostgreSQL
                                ↓
                        Query Results
                                ↓
                        JSON Response
                                ↓
                        ALB → User
```

## Monitoring Architecture

### CloudWatch Agent Configuration

```
┌─────────────────────────────────────────────────┐
│  CloudWatch Agent (EC2)                         │
│  ┌───────────────────────────────────────────┐ │
│  │  Metrics Collection (60s interval)        │ │
│  │  • CPU: per-core and total                │ │
│  │  • Memory: used, available, cached        │ │
│  │  • Disk: usage, I/O, inodes              │ │
│  │  • Network: bytes, packets, errors       │ │
│  │  • Swap: used, free                      │ │
│  └───────────────────────────────────────────┘ │
│                                                 │
│  ┌───────────────────────────────────────────┐ │
│  │  Log Collection                           │ │
│  │  • /var/log/syslog                        │ │
│  │  • /var/log/user-data.log                 │ │
│  │  • Docker container logs                  │ │
│  └───────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  CloudWatch                                     │
│  ┌───────────────────────────────────────────┐ │
│  │  Metrics (Custom Namespace: CWAgent)      │ │
│  │  ┌─────────────────────────────────────┐ │ │
│  │  │ CPUUtilization                      │ │ │
│  │  │ MemoryUsedPercent                   │ │ │
│  │  │ DiskUsedPercent                     │ │ │
│  │  │ NetworkBytesIn/Out                  │ │ │
│  │  └─────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────┘ │
│                                                 │
│  ┌───────────────────────────────────────────┐ │
│  │  Logs (Log Groups)                        │ │
│  │  • /aws/ec2/startuphub-dev/system         │ │
│  │  • /aws/ec2/startuphub-dev/user-data      │ │
│  │  • /aws/ec2/startuphub-dev/docker         │ │
│  └───────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  CloudWatch Alarms                              │
│  ┌───────────────────────────────────────────┐ │
│  │  • CPU > 80% for 10 min → SNS Alert      │ │
│  │  • Memory > 80% for 10 min → SNS Alert   │ │
│  │  • Disk > 90% for 10 min → SNS Alert     │ │
│  └───────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  SNS Topic                                      │
│  ┌───────────────────────────────────────────┐ │
│  │  Email: osikanyie@gmail.com              │ │
│  └───────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

### Dashboard Widgets

```
┌─────────────────────────────────────────────────────────────┐
│  CloudWatch Dashboard: startuphub-dev-dashboard             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────┐  ┌──────────────────────┐        │
│  │ EC2 CPU Utilization  │  │ EC2 Memory Usage     │        │
│  │ (ASG Average)        │  │ (ASG Average)        │        │
│  │ [Time Series Graph]  │  │ [Time Series Graph]  │        │
│  └──────────────────────┘  └──────────────────────┘        │
│                                                              │
│  ┌──────────────────────┐  ┌──────────────────────┐        │
│  │ ALB Request Count    │  │ ALB Response Time    │        │
│  │ (Sum per 5 min)      │  │ (Average latency)    │        │
│  │ [Time Series Graph]  │  │ [Time Series Graph]  │        │
│  └──────────────────────┘  └──────────────────────┘        │
│                                                              │
│  ┌──────────────────────┐  ┌──────────────────────┐        │
│  │ ALB Healthy Hosts    │  │ RDS CPU Utilization  │        │
│  │ (Count)              │  │ (Average)            │        │
│  │ [Time Series Graph]  │  │ [Time Series Graph]  │        │
│  └──────────────────────┘  └──────────────────────┘        │
│                                                              │
│  ┌──────────────────────┐  ┌──────────────────────┐        │
│  │ RDS DB Connections   │  │ RDS Free Storage     │        │
│  │ (Count)              │  │ (Bytes)              │        │
│  │ [Time Series Graph]  │  │ [Time Series Graph]  │        │
│  └──────────────────────┘  └──────────────────────┘        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## CI/CD Architecture

### GitHub Actions Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  Developer pushes to main branch                            │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  Job 1: Validate Terraform                                  │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • Checkout code                                      │ │
│  │ • Setup Terraform                                    │ │
│  │ • terraform fmt -check -recursive                    │ │
│  │ • terraform validate                                 │ │
│  └───────────────────────────────────────────────────────┘ │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  Job 2: Build and Push Docker Image                         │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • Configure AWS credentials (OIDC)                   │ │
│  │ • Login to Amazon ECR                                │ │
│  │ • Build Docker image from app/                       │ │
│  │ • Tag with commit SHA and 'latest'                   │ │
│  │ • Push to ECR repository                             │ │
│  └───────────────────────────────────────────────────────┘ │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  Job 3: Terraform Plan                                      │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • Configure AWS credentials (OIDC)                   │ │
│  │ • Setup Terraform                                    │ │
│  │ • Generate terraform.tfvars from GitHub Secrets      │ │
│  │ • terraform init                                     │ │
│  │ • terraform plan -out=tfplan                         │ │
│  │ • Upload plan as artifact                            │ │
│  └───────────────────────────────────────────────────────┘ │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  Job 4: Terraform Apply                                     │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • Configure AWS credentials (OIDC)                   │ │
│  │ • Setup Terraform                                    │ │
│  │ • Generate terraform.tfvars from GitHub Secrets      │ │
│  │ • terraform init                                     │ │
│  │ • terraform apply -auto-approve                      │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Secrets Management

```
┌─────────────────────────────────────────────────────────────┐
│  GitHub Repository Secrets                                  │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • AWS_ROLE_ARN (OIDC role ARN)                       │ │
│  │ • TF_VAR_project_name                                │ │
│  │ • TF_VAR_region                                      │ │
│  │ • TF_VAR_vpc_cidr                                    │ │
│  │ • TF_VAR_public_subnet_1_cidr                        │ │
│  │ • TF_VAR_public_subnet_2_cidr                        │ │
│  │ • TF_VAR_private_subnet_1_cidr                       │ │
│  │ • TF_VAR_private_subnet_2_cidr                       │ │
│  │ • TF_VAR_private_db_subnet_1_cidr                    │ │
│  │ • TF_VAR_private_db_subnet_2_cidr                    │ │
│  │ • TF_VAR_alb_http_cidr                               │ │
│  │ • TF_VAR_alb_https_cidr                              │ │
│  │ • TF_VAR_ami_id                                      │ │
│  │ • TF_VAR_instance_type                               │ │
│  │ • TF_VAR_desired_capacity                            │ │
│  │ • TF_VAR_min_size                                    │ │
│  │ • TF_VAR_max_size                                    │ │
│  │ • TF_VAR_enable_deletion_protection                  │ │
│  │ • TF_VAR_force_delete                                │ │
│  │ • TF_VAR_db_engine                                   │ │
│  │ • TF_VAR_db_engine_version                           │ │
│  │ • TF_VAR_db_instance_class                           │ │
│  │ • TF_VAR_db_allocated_storage                        │ │
│  │ • TF_VAR_db_name                                     │ │
│  │ • TF_VAR_db_username                                 │ │
│  │ • TF_VAR_db_password                                 │ │
│  │ • TF_VAR_db_multi_az                                 │ │
│  │ • TF_VAR_db_publicly_accessible                      │ │
│  │ • TF_VAR_db_deletion_protection                      │ │
│  │ • TF_VAR_ecr_repository_name                         │ │
│  │ • TF_VAR_ecr_image_tag_mutability                    │ │
│  │ • TF_VAR_ecr_scan_on_push                            │ │
│  │ • TF_VAR_ecr_image_tag                               │ │
│  │ • TF_VAR_github_repository                           │ │
│  │ • TF_VAR_alert_email                                 │ │
│  │ • TF_VAR_waf_rate_limit                              │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│  GitHub Actions Workflow                                    │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • Reads secrets during workflow execution            │ │
│  │ • Generates terraform.tfvars dynamically             │ │
│  │ • Secrets never exposed in logs or artifacts         │ │
│  │ • Encrypted in transit and at rest                   │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Strategies

### Current: Rolling Deployment

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 1: Terraform Apply                                   │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • Updates Launch Template with new configuration     │ │
│  │ • ASG performs rolling update                        │ │
│  │ • Old instances terminated gracefully                │ │
│  │ • New instances launched with updated config         │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 2: Docker Image Update                               │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • CI/CD pushes new image to ECR                      │ │
│  │ • EC2 instances pull new image on next deployment    │ │
│  │ • Container restarts with new code                   │ │
│  │ • Zero downtime (rolling update)                     │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Future: Blue/Green Deployment (Planned)

```
┌─────────────────────────────────────────────────────────────┐
│  Blue Environment (Current Production)                      │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • ALB → Blue Target Group                            │ │
│  │ • EC2 instances running v1.0.0                       │ │
│  │ • Serving production traffic                         │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Green Environment (New Deployment)                         │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • EC2 instances running v2.0.0                       │ │
│  │ • Health checks passing                              │ │
│  │ • Not receiving traffic yet                          │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│  Traffic Switch                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • ALB switches to Green Target Group                 │ │
│  │ • Instant traffic cutover                            │ │
│  │ • Blue environment on standby                        │ │
│  │ • Instant rollback if needed                         │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Scalability

### Horizontal Scaling

```
┌─────────────────────────────────────────────────────────────┐
│  Auto Scaling Group Configuration                           │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • Min size: 2 instances                              │ │
│  │ • Max size: 4 instances                              │ │
│  │ • Desired capacity: 2 instances                      │ │
│  │ • Health check type: ELB                             │ │
│  │ • Health check grace period: 300 seconds             │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│  Scaling Policies (Future)                                  │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • Target tracking: CPU < 70%                         │ │
│  │ • Scale out: Add 1 instance when CPU > 70%           │ │
│  │ • Scale in: Remove 1 instance when CPU < 30%         │ │
│  │ • Cooldown: 300 seconds                              │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Vertical Scaling

```
Current Instance Type: t3.micro
• 2 vCPUs
• 1 GB RAM
• Suitable for: Development, low traffic

Upgrade Path:
• t3.small (2 vCPU, 2 GB RAM) - Medium traffic
• t3.medium (2 vCPU, 4 GB RAM) - High traffic
• t3.large (2 vCPU, 8 GB RAM) - Very high traffic

RDS Instance Type: db.t3.micro
• 2 vCPUs
• 1 GB RAM
• Suitable for: Development, small database

Upgrade Path:
• db.t3.small (2 vCPU, 2 GB RAM) - Medium workload
• db.t3.medium (2 vCPU, 4 GB RAM) - High workload
```

## High Availability

### Multi-AZ Deployment

```
┌─────────────────────────────────────────────────────────────┐
│  Availability Zone 1 (us-east-1a)                           │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • Public Subnet: ALB node 1                          │ │
│  │ • Private Subnet: EC2 instance 1                     │ │
│  │ • Private DB Subnet: RDS primary                     │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Availability Zone 2 (us-east-1b)                           │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • Public Subnet: ALB node 2                          │ │
│  │ • Private Subnet: EC2 instance 2                     │ │
│  │ • Private DB Subnet: RDS standby                     │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

Benefits:
• Fault tolerance: AZ failure doesn't affect availability
• Load distribution: Traffic spread across AZs
• Data redundancy: RDS replicated across AZs
```

## Cost Optimization

### Resource Sizing

```
Development Environment:
• EC2: t3.micro ($0.0116/hour = $8.47/month)
• RDS: db.t3.micro ($0.018/hour = $13.14/month)
• NAT Gateway: $0.045/hour = $32.85/month
• ALB: $0.025/hour = $18.25/month

Total Base Cost: ~$72.71/month

Additional Costs:
• Data transfer: ~$5/month
• S3 (Terraform state): ~$0.50/month
• CloudWatch: ~$10/month
• ECR: ~$1/month
• WAF: ~$10/month

Estimated Total: ~$99.21/month
```

### Cost Reduction Strategies

```
1. Reserved Instances (30-40% savings)
   • 1-year reserved: 30% discount
   • 3-year reserved: 40% discount

2. Spot Instances (70-90% savings)
   • Suitable for stateless workloads
   • 2-minute interruption notice

3. Auto Scaling
   • Scale down during off-hours
   • Scale up during peak hours

4. Right-sizing
   • Monitor actual utilization
   • Downsize over-provisioned resources

5. NAT Gateway Optimization
   • Use VPC endpoints for AWS services
   • Reduce data transfer costs
```

## Compliance & Audit

### Logging & Monitoring

```
┌─────────────────────────────────────────────────────────────┐
│  AWS CloudTrail                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • API call logging                                   │ │
│  │ • User activity tracking                             │ │
│  │ • Resource changes                                   │ │
│  │ • Security event monitoring                          │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Application Logs                                           │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • Docker container stdout/stderr                     │ │
│  │ • Node.js application logs                           │ │
│  │ • Database query logs                                │ │
│  │ • Error tracking                                     │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  System Logs                                                │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ • OS-level logs (/var/log/syslog)                    │ │
│  │ • Docker daemon logs                                 │ │
│  │ • CloudWatch Agent logs                              │ │
│  │ • User data execution logs                           │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Security Compliance

```
✅ No hardcoded credentials
✅ IAM roles with least privilege
✅ Encryption at rest (EBS, RDS)
✅ Encryption in transit (TLS - future)
✅ Network isolation (private subnets)
✅ Security groups (stateful firewall)
✅ WAF protection (OWASP Top 10)
✅ Secrets Manager for sensitive data
✅ CloudTrail for audit logging
✅ CloudWatch for monitoring
```

## Disaster Recovery

### Backup Strategy

```
RDS Automated Backups:
• Retention: 7 days
• Backup window: 03:00-04:00 UTC
• Point-in-time recovery: Enabled

Terraform State:
• S3 bucket: Versioning enabled
• Location: us-east-1
• Encryption: AES-256

Application Data:
• Database: Automated backups
• Container images: ECR (immutable tags)
• Infrastructure: Terraform (reproducible)
```

### Recovery Procedures

```
Scenario 1: Single Instance Failure
• ASG automatically launches replacement
• No manual intervention required
• Recovery time: 3-5 minutes

Scenario 2: Availability Zone Failure
• ALB routes traffic to healthy AZ
• ASG launches instances in healthy AZ
• No data loss (RDS replicated)
• Recovery time: 5-10 minutes

Scenario 3: Complete Infrastructure Loss
• terraform apply recreates everything
• Restore RDS from backup
• Re-push Docker images
• Recovery time: 30-60 minutes
```

## Performance Benchmarks

### Expected Performance

```
Application Response Time:
• Health check (/): < 50ms
• API endpoints: < 200ms
• Database queries: < 100ms

Throughput:
• Single instance: ~500 req/sec
• Two instances: ~1000 req/sec
• Four instances: ~2000 req/sec

Database Performance:
• Read queries: < 50ms
• Write queries: < 100ms
• Connections: Up to 66 (db.t3.micro)
```

### Monitoring Thresholds

```
CPU Utilization:
• Warning: > 70%
• Critical: > 80%
• Action: Scale out or optimize

Memory Usage:
• Warning: > 75%
• Critical: > 85%
• Action: Scale up or optimize

Disk Usage:
• Warning: > 80%
• Critical: > 90%
• Action: Clean up or expand

Response Time:
• Warning: > 500ms
• Critical: > 1000ms
• Action: Investigate and optimize
```

## Future Enhancements

### Planned Improvements

```
1. HTTPS & SSL/TLS
   • ACM certificate
   • HTTPS listener on ALB
   • HTTP → HTTPS redirect

2. DNS & Domain
   • Route53 hosted zone
   • Custom domain name
   • DNS-based routing

3. Container Orchestration
   • ECS Fargate migration
   • Service discovery
   • Load balancing

4. Advanced Monitoring
   • X-Ray distributed tracing
   • CloudWatch Synthetics
   • Custom metrics

5. Security Enhancements
   • VPC endpoints
   • PrivateLink
   • Enhanced WAF rules

6. Deployment Strategies
   • Blue/Green deployments
   • Canary deployments
   • Feature flags
```

## Conclusion

This architecture provides a production-ready foundation for the StartupHub application with:

✅ High availability (multi-AZ)
✅ Security (defense in depth)
✅ Scalability (auto scaling)
✅ Observability (monitoring & logging)
✅ Automation (CI/CD pipeline)
✅ Cost optimization (right-sized)
✅ Compliance (audit logging)

The modular design allows for incremental improvements and future enhancements while maintaining operational excellence.
