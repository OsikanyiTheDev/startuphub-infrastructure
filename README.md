# StartupHub AWS Infrastructure (Terraform)

<div align="center">

**Production-Grade AWS Infrastructure with Full CI/CD Automation**

[![Terraform](https://img.shields.io/badge/Terraform-1.9.8-blue.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-orange.svg)](https://aws.amazon.com/)
[![Docker](https://img.shields.io/badge/Docker-Container-2496ED.svg)](https://www.docker.com/)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF.svg)](https://github.com/features/actions)
[![Version](https://img.shields.io/badge/Version-1.0.0-green.svg)](https://github.com/OsikanyiTheDev/startuphub-infrastructure/releases/tag/v1.0.0)

</div>

---

## Overview

StartupHub Infrastructure is a production-ready AWS cloud environment built using **Terraform Infrastructure as Code (IaC)** with full CI/CD automation. This project demonstrates enterprise-level cloud architecture with containerized applications, comprehensive security, and automated operations.

**Key Achievements:**
- ✅ 13 reusable Terraform modules
- ✅ Fully automated CI/CD pipeline
- ✅ Zero hardcoded credentials (OIDC + Secrets Manager)
- ✅ Production-grade security (WAF, IAM, encryption)
- ✅ Complete observability (CloudWatch logs, metrics, alarms)
- ✅ High availability (multi-AZ, auto-scaling ready)

---

## 📚 Documentation

Comprehensive documentation is available in the following files:

| Document | Description |
|----------|-------------|
| **[ARCHITECTURE.md](./ARCHITECTURE.md)** | Detailed system architecture with diagrams |
| **[DEPLOYMENT.md](./DEPLOYMENT.md)** | Step-by-step deployment guide |
| **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** | Common issues and solutions |
| **[COST.md](./COST.md)** | Detailed cost analysis and optimization |
| **[RELEASE_NOTES_v1.0.0.md](./RELEASE_NOTES_v1.0.0.md)** | v1.0.0 release announcement |
| **[CHANGELOG.md](./CHANGELOG.md)** | Complete version history |
| **[milestone-history.md](./milestone-history.md)** | Project evolution and lessons learned |

---

## Quick Start

Deploy the entire infrastructure in 30 minutes:

```bash
# 1. Clone repository
git clone git@github.com:OsikanyiTheDev/startuphub-infrastructure.git
cd startuphub-infrastructure

# 2. Configure AWS credentials
aws configure

# 3. Initialize Terraform
cd environments/dev
terraform init

# 4. Deploy Phase 1: Infrastructure (10-15 min)
terraform apply

# 5. Deploy Phase 2: Docker Image (2-5 min)
cd ../..
./scripts/build-and-push.sh

# 6. Deploy Phase 3: EC2 Instances (5-10 min)
cd environments/dev
# Update terraform.tfvars: desired_capacity = 2
terraform apply

# 7. Access application
terraform output alb_dns_name
# Open http://<alb-dns-name> in browser
```

**For detailed instructions, see [DEPLOYMENT.md](./DEPLOYMENT.md)**

---

## Architecture Overview

```
                              Internet
                                  |
                                  |
                        AWS WAF v2 WebACL
                    (Rate limiting, SQLi, XSS,
                     IP reputation, bot protection)
                                  |
                                  |
                     Application Load Balancer
                           (Port 80)
                                  |
                                  |
                     Target Group (Port 3000)
                                  |
                                  |
                     Auto Scaling Group
                                  |
                    --------------|--------------
                    |                            |
              Private Subnet 1            Private Subnet 2
                    |                            |
              EC2 Instance 1              EC2 Instance 2
              (Docker Host)               (Docker Host)
                    |                            |
                    +--------|---------|---------+
                             |         |
                    Amazon ECR    AWS Secrets Manager
                  (Container      (Database
                   Registry)      Credentials)
                                   |
                             RDS PostgreSQL
                          (Private Subnet)
```

---

## CI/CD Pipeline

### Automated Deployment Workflow

Every push to the `main` branch triggers a fully automated deployment pipeline:

```
git push origin main
    ↓
GitHub Actions starts automatically
    ↓
┌─────────────────────────────────┐
│ 1. Validate Terraform           │
│    - terraform fmt -check       │
│    - terraform validate         │
└────────────────┬────────────────┘
                 ↓
┌─────────────────────────────────┐
│ 2. Build & Push Docker Image    │
│    - Build from app/            │
│    - Push to ECR                │
└────────────────┬────────────────┘
                 ↓
┌─────────────────────────────────┐
│ 3. Terraform Plan               │
│    - Read secrets               │
│    - Show changes               │
└────────────────┬────────────────┘
                 ↓
┌─────────────────────────────────┐
│ 4. Terraform Apply              │
│    - Deploy changes             │
└─────────────────────────────────┘
```

### Secrets Management

All 35 infrastructure variables are stored securely in GitHub Secrets:

- ✅ Zero secrets in git repository
- ✅ Encrypted at rest in GitHub
- ✅ Automatically injected during workflow runs
- ✅ Easy rotation via `gh secret set` command

**Key Features:**
- OIDC authentication (no AWS access keys)
- Path-based triggers (only runs when relevant files change)
- Automatic validation, build, and deployment
- Full audit trail in GitHub Actions

---

## AWS Services Used

### Networking

The networking layer provides a secure multi-tier VPC architecture.

Services used:

- Amazon VPC
- Public Subnets (ALB)
- Private Application Subnets (EC2)
- Private Database Subnets (RDS)
- Internet Gateway
- NAT Gateway
- Route Tables
- Elastic IP

---

### Compute Layer

The compute layer runs containerized application workloads using EC2 instances.

Services used:

- Amazon EC2
- EC2 Launch Templates
- Auto Scaling Groups
- IAM Instance Profiles
- Docker Runtime

Features:

- Containerized application deployment
- Automatic scaling
- Encrypted EBS volumes
- IMDSv2 enabled
- Monitoring enabled
- Automatic Docker installation via user data

---

### Container Registry

Container images are stored and managed in Amazon ECR.

Services used:

- Amazon Elastic Container Registry (ECR)
- ECR Lifecycle Policies
- IAM Policies for ECR access

Features:

- Private container registry
- Automated image scanning
- IAM-based access control
- Version management

---

### Load Balancing

The application uses an Application Load Balancer.

Configuration:

- Listener: Port 80 (HTTP)
- Target Group: Port 3000 (Application)
- Health Check: `/` endpoint

Benefits:

- High availability
- Traffic distribution
- Health checks
- Easy scaling

---

### Database Layer

The database layer uses Amazon RDS PostgreSQL.

Features:

- PostgreSQL 16
- Private database subnets
- Encryption enabled
- Automated backups
- Database security group isolation
- No public accessibility
- Credentials managed via AWS Secrets Manager

Database access flow:

```
EC2 Container
      |
      |
Private Network
      |
      |
Amazon RDS PostgreSQL
```

Only EC2 instances are allowed to communicate with the database.

---

## Security Architecture

### Removal of SSH Access

This project removes direct SSH access to EC2 instances.

The secure approach:

```
Developer
    |
    |
AWS Systems Manager Session Manager
    |
    |
EC2 Instance
```

Benefits:

- No exposed SSH ports
- No SSH keys required
- Better auditing
- Centralized access management
- Reduced attack surface

---

### IAM Security

The EC2 instances use IAM Roles for:

- AWS Systems Manager access
- Amazon ECR read access
- AWS Secrets Manager access
- Secure AWS service communication

IAM follows the principle of least privilege access.

---

### Secrets Management

Database credentials are not stored in:

- Terraform variables
- Source code
- Configuration files

Instead, credentials are managed using:

```
Amazon RDS
      |
      |
AWS Secrets Manager
      |
      |
EC2 IAM Role (Runtime Access)
```

The EC2 instance retrieves credentials at runtime and passes them to the container.

Permission granted:

```
secretsmanager:GetSecretValue
```

---

## Container Deployment

### Docker Application

The application is a Node.js/Express web server:

- Runs on port 3000
- Connects to PostgreSQL database
- Reads configuration from environment variables
- Provides REST API endpoints

### Build and Push Process

Container images are built and pushed using automation scripts:

```bash
./scripts/build-and-push.sh dev ./app latest
```

The script:

1. Builds the Docker image from `./app` directory
2. Tags the image with the specified version
3. Authenticates with Amazon ECR
4. Pushes the image to ECR repository

### EC2 Instance Initialization

When EC2 instances launch, user data automatically:

1. Installs Docker runtime
2. Installs AWS CLI v2
3. Authenticates with Amazon ECR
4. Pulls the latest container image
5. Retrieves database credentials from Secrets Manager
6. Starts the container with environment variables
7. Exposes port 3000 for ALB health checks

---

## Terraform Project Structure

```
startuphub-infrastructure/
│
├── .github/
│   └── workflows/
│       └── ci-cd.yml              # CI/CD pipeline definition
│
├── app/                          # Application source code
│   ├── Dockerfile
│   ├── server.js
│   ├── package.json
│   └── .dockerignore
│
├── scripts/                      # Automation scripts
│   ├── build-and-push.sh
│   └── set-github-secrets.sh     # Gitignored (contains secrets)
│
├── environments/
│   └── dev/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars        # Gitignored (contains secrets)
│       ├── outputs.tf
│       └── backend.tf
│
├── modules/
│   ├── alb/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── autoscaling/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── cloudwatch-alarms/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── cloudwatch-dashboard/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── cloudwatch-logs/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── compute/
│   │   ├── main.tf
│   │   ├── iam.tf
│   │   ├── user_data.tpl
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── ecr/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── iam/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── rds/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── security/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── sns/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── docs/
│   └── CI-CD-SETUP.md
│
├── README.md
├── dependencies.md
├── milestone-history.md
└── .gitignore
```

---

## Monitoring & Observability

The infrastructure includes comprehensive monitoring and logging capabilities for production-grade operations.

### CloudWatch Logs

Four log groups capture all system activity:

| Log Group | Source | Retention |
|-----------|--------|-----------|
| `/aws/ec2/{project}/system` | System logs (`/var/log/syslog`) | 30 days |
| `/aws/ec2/{project}/docker` | Docker container logs | 30 days |
| `/aws/ec2/{project}/application` | Application logs | 30 days |
| `/aws/ec2/{project}/user-data` | EC2 initialization logs | 30 days |

Access logs via AWS Console → CloudWatch → Log groups, or use AWS CLI:

```bash
aws logs tail /aws/ec2/startuphub-dev/docker --follow
```

### CloudWatch Agent

EC2 instances run the CloudWatch Agent to collect custom metrics:

- **CPU**: Active, idle, user, system (per core and total)
- **Memory**: Used percent, available percent
- **Disk**: Usage percent per mount point, inodes free
- **Network**: Bytes/packets sent/received per interface
- **Swap**: Used percent

### CloudWatch Dashboard

Access the unified dashboard at `startuphub-dev-dashboard` in CloudWatch Console.

Widgets include:
- EC2 CPU utilization (ASG average)
- EC2 memory used percent
- ALB request count
- ALB target response time
- ALB healthy host count
- RDS CPU utilization
- RDS database connections
- RDS free storage space

### CloudWatch Alarms

**CPU Alarm**: Triggers when ASG average CPU exceeds 80% for 10 minutes (2 consecutive 5-minute periods).

Notifications are sent via SNS to `osikanyie@gmail.com`.

**Important**: After initial deployment, check your email and click the SNS subscription confirmation link to activate email notifications.

---

## Web Application Firewall (WAF)

The ALB is protected by AWS WAF v2 with multiple layers of security:

### Active Rules

| Rule | Priority | Protection |
|------|----------|------------|
| **Rate Limiting** | 1 | Blocks IPs exceeding 2000 requests per 5 minutes |
| **AWS Common Rules** | 2 | SQLi, XSS, RCE, SSRF, path traversal |
| **SQL Injection** | 3 | Database attack patterns |
| **Known Bad Inputs** | 4 | RCE, Java deserialization attacks |
| **IP Reputation** | 5 | Blocks known malicious IP addresses |

### WAF Capabilities

**Rate Limiting**:
- Prevents DDoS attacks
- Configurable threshold (default: 2000 req/5min per IP)
- CloudWatch metrics for monitoring

**SQL Injection Protection**:
- Blocks SQL injection attempts in query strings, headers, and body
- Protects database from unauthorized access

**Cross-Site Scripting (XSS) Protection**:
- Filters malicious JavaScript injection attempts
- Prevents session hijacking and data theft

**IP Reputation**:
- Automatically blocks known malicious IP addresses
- Updated regularly by AWS threat intelligence

**CloudWatch Metrics**:
- `BlockedRequests` - Count of blocked requests
- `AllowedRequests` - Count of allowed requests
- Real-time monitoring of attack patterns

### Testing WAF Protection

**Test Rate Limiting**:
```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
for i in {1..100}; do
  curl -s -o /dev/null -w "%{http_code}\n" http://$ALB_DNS/
done
```

**Test SQL Injection Blocking**:
```bash
curl "http://your-alb-dns/?id=1' OR '1'='1"
# Should return 403 Forbidden
```

**View Blocked Requests**:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/WAFV2 \
  --metric-name BlockedRequests \
  --dimensions Name=WebACL,Value=startuphub-dev-web-acl \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum
```

---

## Deployment Workflow

### Automated Deployment (Recommended)

Simply push to main branch:

```bash
git add .
git commit -m "feat: update infrastructure"
git push origin main
```

The CI/CD pipeline automatically:
1. Validates Terraform code
2. Builds and pushes Docker image to ECR
3. Runs terraform plan
4. Applies infrastructure changes

### Manual Deployment (Three-Phase)

For initial setup or when CI/CD is not configured:

#### Phase 1: Infrastructure Setup

```bash
cd environments/dev
terraform init
terraform apply
```

This creates all resources except EC2 instances (desired_capacity = 0).

#### Phase 2: Build and Push Application

```bash
cd ../..
./scripts/build-and-push.sh dev ./app latest
```

#### Phase 3: Launch EC2 Instances

Update `terraform.tfvars`:
```hcl
desired_capacity = 2
min_size         = 2
```

Apply changes:
```bash
terraform apply
```

---

### Access the Application

Retrieve the ALB DNS name:

```bash
terraform output alb_dns_name
```

Visit the URL in your browser:

```
http://<alb-dns-name>
```

---

## Disaster Recovery

### Complete Recovery Process (20 minutes from zero)

```bash
# 1. Clone and configure
git clone git@github.com:OsikanyiTheDev/startuphub-infrastructure.git
cd startuphub-infrastructure
aws configure

# 2. Deploy infrastructure
cd environments/dev
terraform init
terraform apply

# 3. Push Docker image
cd ../..
./scripts/build-and-push.sh dev ./app latest

# 4. Launch EC2 instances
cd environments/dev
# Edit terraform.tfvars: desired_capacity = 2
terraform apply

# 5. Setup CI/CD (optional)
cd ..
gh auth login
./scripts/set-github-secrets.sh
```

---

## Current Features

✅ Modular Terraform architecture
✅ Custom AWS VPC design
✅ Public and private subnet separation
✅ NAT Gateway configuration
✅ Application Load Balancer
✅ EC2 Launch Template
✅ Auto Scaling Group
✅ Docker container deployment
✅ Amazon ECR integration
✅ IAM Role based EC2 access
✅ AWS Systems Manager access
✅ Secrets Manager integration
✅ Private PostgreSQL RDS database
✅ Security Group isolation
✅ Encrypted storage
✅ Infrastructure as Code approach
✅ **GitHub Actions CI/CD pipeline**
✅ **Automated deployments on git push**
✅ **35 secrets managed in GitHub**
✅ **OIDC authentication (no AWS keys)**
✅ **CloudWatch centralized logging**
✅ **CloudWatch Agent for custom metrics**
✅ **CloudWatch dashboard with 8 widgets**
✅ **CloudWatch alarms with SNS notifications**
✅ **Production-grade observability**
✅ **AWS WAF v2 Web Application Firewall**
✅ **SQL Injection protection**
✅ **XSS (Cross-Site Scripting) protection**
✅ **Rate limiting (DDoS protection)**
✅ **IP reputation filtering**

---

## Future Improvements

Planned improvements:

- HTTPS with ACM certificates
- Route53 DNS integration
- Blue/Green deployments
- Container orchestration with ECS/EKS
- Multi-environment (dev/staging/prod)
- Enhanced CloudWatch alarms (memory, disk, RDS)
- CloudWatch Synthetics for uptime monitoring

---

## Skills Demonstrated

This project demonstrates practical experience with:

- Terraform
- AWS Cloud Architecture
- Infrastructure as Code
- Containerization (Docker)
- Amazon ECR
- Networking
- IAM Security
- EC2 Management
- Load Balancing
- Auto Scaling
- Database Security
- Secrets Management
- DevOps Practices
- Automation Scripting
- **GitHub Actions CI/CD**
- **OIDC Authentication**
- **Infrastructure Automation**
- **AWS WAF (Web Application Firewall)**
- **Web Security (SQLi, XSS, DDoS protection)**

---

## Author

**Osikanyi Essandoh**
**OsikanyiTheDev**

Cloud Engineering / DevOps Portfolio Project

---

## Version History

- **v1.0.0** - Production Release (Comprehensive documentation, ARCHITECTURE.md, DEPLOYMENT.md, TROUBLESHOOTING.md, COST.md, RELEASE_NOTES, CHANGELOG)
- **v0.9.0** - WAF (Web Application Firewall) protection (Rate limiting, SQLi, XSS, IP reputation)
- **v0.8.0** - Skipped (HTTPS/ACM - requires domain ownership)
- **v0.7.0** - Monitoring & Logging (CloudWatch Logs, Agent, Alarms, Dashboard, SNS)
- **v0.6.0** - CI/CD pipeline with GitHub Actions automation
- **v0.5.0** - Docker/ECR integration with containerized deployment
- **v0.4.0** - RDS PostgreSQL with Secrets Manager
- **v0.3.0** - Security hardening (IAM, SSM, encryption)
- **v0.2.0** - Load balancer and auto scaling
- **v0.1.0** - Initial VPC and networking setup

For detailed release information, see [RELEASE_NOTES_v1.0.0.md](./RELEASE_NOTES_v1.0.0.md) and [CHANGELOG.md](./CHANGELOG.md).
