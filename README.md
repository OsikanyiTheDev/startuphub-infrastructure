# StartupHub AWS Infrastructure (Terraform)

## Overview

StartupHub Infrastructure is a production-style AWS cloud environment built using **Terraform Infrastructure as Code (IaC)** with full CI/CD automation.

This project provisions and manages a secure, scalable, and highly available AWS architecture using Terraform modules with containerized application deployment and automated deployment pipelines.

The infrastructure follows AWS best practices by:

- Separating workloads into public and private networks
- Deploying containerized applications via Amazon ECR
- Using AWS Systems Manager for secure instance management
- Implementing IAM least-privilege access
- Storing database credentials securely using AWS Secrets Manager
- Auto-scaling containerized workloads
- Deploying resources using reusable Terraform modules
- **Automating deployments via GitHub Actions CI/CD pipeline**

---

## Architecture Overview

```
                              Internet
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

All 32 infrastructure variables are stored securely in GitHub Secrets:

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
│   └── security/
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
✅ **32 secrets managed in GitHub**
✅ **OIDC authentication (no AWS keys)**

---

## Future Improvements

Planned improvements:

- HTTPS with ACM certificates
- Route53 DNS integration
- CloudWatch monitoring and alarms
- Centralized logging
- AWS WAF integration
- Blue/Green deployments
- Container orchestration with ECS/EKS
- Multi-environment (dev/staging/prod)

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

---

## Author

**Osikanyi Essandoh**
**OsikanyiTheDev**

Cloud Engineering / DevOps Portfolio Project

---

## Version History

- **v0.6.0** - CI/CD pipeline with GitHub Actions automation
- **v0.5.0** - Docker/ECR integration with containerized deployment
- **v0.4.0** - RDS PostgreSQL with Secrets Manager
- **v0.3.0** - Security hardening (IAM, SSM, encryption)
- **v0.2.0** - Load balancer and auto scaling
- **v0.1.0** - Initial VPC and networking setup
