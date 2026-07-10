

# v0.4.0 - Docker & ECR Integration (Current)

**Date:** July 2026

## Overview

Transitioned from static Nginx user_data to a full containerized application deployment pipeline.

The infrastructure now provisions an Amazon ECR repository, and EC2 instances automatically pull and run a Docker container at launch. The application connects to the PostgreSQL RDS instance using credentials fetched from AWS Secrets Manager at runtime.

A two-phase deployment strategy eliminates the race condition between image availability and instance launch.

---

# New Module: ECR

Added a new `modules/ecr/` module that creates the Amazon Elastic Container Registry repository.

```
modules/ecr/
├── main.tf        # aws_ecr_repository resource
├── variables.tf   # project_name, image_tag_mutability, scan_on_push
└── outputs.tf     # repository_url, repository_name, repository_arn
```

Configuration is fully explicit — no defaults in the module. All values are declared in `environments/dev/terraform.tfvars`.

---

# Docker Application

Created a production-style Task Manager application:

```
app/
├── Dockerfile       # Multi-stage build, non-root user, health check
├── package.json     # Node.js + Express + pg
└── server.js        # REST API with PostgreSQL connection
```

Features:
- Health check endpoint (`/`) returns 200 for ALB
- Task CRUD API (`/api/tasks`)
- Auto-creates `tasks` table on startup
- Database connection via environment variables
- Multi-stage Dockerfile for minimal image size
- Runs as non-root user (`appuser`)

---

# Build & Push Automation Script

Added `scripts/build-and-push.sh` for automated Docker image deployment:

```bash
./scripts/build-and-push.sh <environment> <dockerfile_dir> [image_tag]

# Example:
./scripts/build-and-push.sh dev ./app latest
```

The script:
1. Validates prerequisites (AWS CLI, Docker, Terraform)
2. Reads ECR repository URL from Terraform output
3. Authenticates with ECR using AWS CLI
4. Builds the Docker image
5. Tags and pushes to ECR

---

# Compute Module Updates

Converted `user_data.sh` to `user_data.tpl` (Terraform template file).

The user_data script now:
1. Installs Docker and AWS CLI v2
2. Authenticates to ECR using the EC2 IAM role (no hardcoded credentials)
3. Pulls the latest Docker image from ECR
4. Fetches the database password from Secrets Manager
5. Runs the container with all required environment variables

New variables added to the compute module:
- `ecr_repository_url`
- `aws_region`
- `image_tag`
- `rds_endpoint`
- `rds_port`
- `rds_db_name`
- `rds_db_user`

All values passed explicitly from the environment layer — no defaults in the module.

---

# IAM Updates

Attached `AmazonEC2ContainerRegistryReadOnly` policy to the EC2 IAM role.

The EC2 instance can now pull images from ECR using only its IAM role. No access keys, no hardcoded credentials.

```
EC2 Instance
      |
      |
IAM Instance Profile
      |
      |
EC2 IAM Role
      |
      ├── AmazonSSMManagedInstanceCore
      ├── AmazonEC2ContainerRegistryReadOnly
      └── RDS Secret Access Policy (scoped)
```

---

# Two-Phase Deployment Strategy

To eliminate the race condition between image availability and instance launch, the infrastructure uses a two-phase deployment approach.

## Phase 1: Create Infrastructure

```bash
cd environments/dev
terraform apply
```

With `desired_capacity = 0` in `terraform.tfvars`:
- ECR repository is created
- Launch template is created
- ASG is created (but with 0 instances)
- RDS is provisioned
- No EC2 instances launch yet

## Phase 2: Push Docker Image

```bash
./scripts/build-and-push.sh dev ./app latest
```

- Docker image is built
- Image is pushed to ECR
- Image now exists in the repository

## Phase 3: Launch EC2 Instances

Update `terraform.tfvars`:
```hcl
desired_capacity = 2
min_size         = 2
```

```bash
terraform apply
```

- ASG launches EC2 instances
- Instances pull image from ECR (image exists)
- Containers start and connect to RDS
- ALB health checks pass
- Application is live

---

# Deployment Data Flow

```
terraform apply (Phase 1)
        |
        ├── Create ECR Repository
        ├── Create Launch Template
        ├── Create ASG (0 instances)
        ├── Create RDS
        └── Create IAM Roles
              |
              v
./scripts/build-and-push.sh (Phase 2)
              |
              └── Push Docker Image to ECR
              |
              v
terraform apply (Phase 3: desired_capacity = 2)
              |
              └── ASG Launches EC2
                    |
                    ├── Install Docker
                    ├── Authenticate to ECR (IAM role)
                    ├── Pull Image from ECR
                    ├── Fetch DB Password (Secrets Manager)
                    ├── Run Container
                    └── ALB Health Check Passes ✅
```

---

# Security Model

```
No Hardcoded Credentials ANYWHERE

EC2 → ECR:            IAM Role (AmazonEC2ContainerRegistryReadOnly)
EC2 → Secrets Manager: IAM Policy (scoped to specific secret ARN)
EC2 → RDS:            Password fetched at runtime from Secrets Manager
Docker Image:          Runs as non-root user
```

---

# Current AWS Architecture

```
                              Internet
                                 |
                                 |
                         Application Load Balancer
                                 |
                                 |
                          Target Group
                                 |
                                 |
                    Auto Scaling Group (Private Subnets)
                                 |
                                 |
                          EC2 Instances
                                 |
              +------------------+------------------+
              |                  |                  |
              |                  |                  |
    AWS Systems Manager   Amazon ECR       AWS Secrets Manager
              |           (Docker Image)          |
              |                  |                  |
         IAM EC2 Role    Pull via IAM Role   RDS Credentials
                                                 |
                                                 |
                                       PostgreSQL RDS
                                       Private Subnets
```

---

# Project Structure

```
startuphub-infrastructure/
├── app/                           # Docker application
│   ├── Dockerfile                 # Multi-stage, non-root
│   ├── package.json               # Node.js dependencies
│   └── server.js                  # Express + PostgreSQL
├── scripts/
│   └── build-and-push.sh          # Docker build & push automation
├── modules/
│   ├── networking/                # VPC, Subnets, IGW, NAT
│   ├── security/                  # Security Groups
│   ├── compute/                   # Launch Template, IAM
│   ├── alb/                       # Application Load Balancer
│   ├── autoscaling/               # Auto Scaling Group
│   ├── rds/                       # PostgreSQL Database
│   └── ecr/                       # Container Registry (NEW)
└── environments/dev/              # Dev environment config
```

---

# Lessons Learned

## Interpolation Errors with templatefile()

The previous attempt to integrate Docker deployment broke Terraform entirely because of interpolation errors.

Root causes:
- Missing variables in the `vars` map
- Hardcoded values that didn't match module outputs
- Too many changes at once making debugging impossible

Solution:
- One small change at a time
- All variables passed explicitly (no defaults in modules)
- Validate after each change before moving on

## Race Condition Prevention

Without the two-phase approach, EC2 instances would attempt to pull an image that doesn't exist yet, causing an infinite loop of failed health checks.

Setting `desired_capacity = 0` during initial deployment ensures the image is available before any instances launch.

---

# Validation Completed

✅ Terraform fmt clean  
✅ Terraform validate successful  
✅ ECR module created  
✅ Docker application built  
✅ Build & push script created  
✅ user_data converted to templatefile  
✅ IAM ECR permissions added  
✅ All variables explicit (no defaults in modules)  
✅ Two-phase deployment strategy documented  

---

# Previous Versions

## v0.3.1 - Secure Rebuild Validation

- Full destroy and rebuild cycle validated.
- SSH access removed.
- EC2 IAM Role with SSM.
- Secrets Manager integration.
- Private RDS deployment.

## v0.2.0 - Compute and Application Layer

- Application Load Balancer.
- EC2 Launch Template.
- Auto Scaling Group.
- Private EC2 deployment.
- Security Groups.

## v0.1.0 - Network Foundation

- Terraform project structure.
- AWS VPC.
- Public and private subnets.
- Internet Gateway.
- NAT Gateway.

---

# Next Milestone

# v0.5.0 - CI/CD Pipeline

Planned improvements:

- GitHub Actions workflow for automated deployment.
- Automated Docker build and push on code merge.
- Blue/Green or Rolling deployment strategy.
- CloudWatch monitoring and alerting.
- Automated ECS/Fargate evaluation.
- Improved observability.

---

# Project Status

Current Version:

```
v0.4.0
```

Status:

```
Docker & ECR Integration Completed
Containerized Application Deployment Pipeline Ready
```

## Overview

Successfully completed a full destroy and rebuild cycle of the StartupHub AWS infrastructure using Terraform.

This milestone validates that the infrastructure is fully reproducible and that all AWS resources can be created entirely from code without manual AWS console configuration.

The architecture now follows stronger cloud security practices by removing SSH access, enforcing IAM-based access, and integrating AWS Secrets Manager for database credential management.

---

# Major Achievements

## Infrastructure Rebuild Validation

Completed a full infrastructure lifecycle test:

- Destroyed previous AWS infrastructure.
- Recreated the complete environment using Terraform.
- Verified Terraform state consistency.
- Confirmed that infrastructure can be rebuilt without manual intervention.
- Validated the reliability of the Infrastructure as Code approach.

---

# Security Improvements

## SSH Access Removed

### Previous Architecture

```
Internet
    |
    |
SSH Port 22
    |
    |
EC2 Instances
```

The previous approach relied on SSH access into EC2 instances.

---

### New Secure Architecture

```
Administrator
      |
      |
AWS Systems Manager
      |
      |
EC2 Instance
```

Benefits:

- No exposed SSH port.
- No SSH key management.
- Improved access auditing.
- Reduced attack surface.
- Better alignment with AWS security best practices.

---

# EC2 IAM Role Integration

Implemented IAM-based EC2 access.

The EC2 instances now use:

- IAM Role
- IAM Instance Profile
- AWS Systems Manager Managed Instance Core Policy

Architecture:

```
EC2 Instance
      |
      |
IAM Instance Profile
      |
      |
EC2 IAM Role
      |
      |
AWS Systems Manager
```

---

# Secrets Management Integration

Implemented AWS Secrets Manager for secure RDS credential storage.

The previous approach of manually managing database credentials has been replaced with AWS-managed secrets.

Architecture:

```
EC2 Application Instance
          |
          |
IAM Permission
          |
          |
AWS Secrets Manager
          |
          |
RDS Generated Password
```

Implemented:

- RDS managed master password.
- Secrets Manager generated secret.
- Least privilege IAM policy.
- EC2 permission restricted to retrieving only the required database secret.

IAM permission:

```
secretsmanager:GetSecretValue
```

Resource scope:

```
Only the StartupHub RDS secret ARN
```

---

# Database Infrastructure

Amazon RDS PostgreSQL deployment completed.

Configuration:

- Engine: PostgreSQL
- Version: 16
- Instance Class: db.t3.micro
- Storage: Encrypted GP3
- Database deployed in private database subnets.
- Public accessibility disabled.
- Backup retention configured.

Security model:

```
EC2 Security Group
        |
        |
Port 5432
        |
        |
RDS Security Group
        |
        |
PostgreSQL Database
```

---

# Current AWS Architecture

```
                         Internet
                            |
                            |
                    Application Load Balancer
                            |
                            |
                     Target Group
                            |
                            |
              Auto Scaling Group (Private Subnets)
                            |
                            |
                     EC2 Instances
                            |
          +-----------------+----------------+
          |                                  |
          |                                  |
 AWS Systems Manager              AWS Secrets Manager
          |                                  |
          |                                  |
     IAM EC2 Role                  RDS Credentials
                                             |
                                             |
                                   PostgreSQL RDS
                                   Private Subnets
```

---

# Terraform Module Structure

Current project structure:

```
startuphub-infrastructure

├── modules
│
├── networking
│   └── VPC
│   └── Subnets
│   └── Route Tables
│   └── NAT Gateway
│
├── security
│   └── Security Groups
│
├── compute
│   └── EC2 Launch Template
│   └── IAM Role
│   └── Instance Profile
│
├── alb
│   └── Application Load Balancer
│
├── autoscaling
│   └── Auto Scaling Group
│
├── rds
│   └── PostgreSQL Database
│
└── environments
    |
    └── dev
        ├── main.tf
        ├── variables.tf
        ├── terraform.tfvars
        └── iam.tf
```

---

# Terraform Lessons Learned

## Resource Ownership

A major lesson from this milestone was maintaining clear ownership of Terraform resources.

Incorrect approach:

```
compute module
        |
        |
        └── RDS Secret Permissions
```

The compute module should only manage compute-related resources.

---

Correct approach:

```
environment layer
        |
        |
        └── Application-specific IAM permissions
```

Terraform modules should manage resources according to their responsibility.

---

# Validation Completed

✅ Terraform destroy completed successfully  
✅ Terraform apply completed successfully  
✅ Infrastructure recreated from code only  
✅ Terraform state clean  
✅ EC2 deployed without SSH access  
✅ AWS Systems Manager access configured  
✅ RDS deployed privately  
✅ Secrets Manager integration completed  
✅ Least privilege IAM implemented  
✅ ALB and Auto Scaling validated  

---

# Previous Versions

## v0.1.0 - Network Foundation

Implemented:

- Terraform project structure.
- AWS VPC.
- Public and private subnets.
- Internet Gateway.
- NAT Gateway.
- Routing architecture.

---

## v0.2.0 - Compute and Application Layer

Implemented:

- Application Load Balancer.
- EC2 Launch Template.
- Auto Scaling Group.
- Private EC2 deployment.
- Security Groups.
- High availability architecture.

---

## v0.3.0 - Security Hardening

Implemented:

- SSH removal.
- EC2 IAM Role.
- AWS Systems Manager access.
- Encrypted EC2 storage.
- IMDSv2 enforcement.
- Private RDS deployment.
- Secrets Manager integration.

---

# Next Milestone

# v0.4.0 - Application Deployment Layer

Planned improvements:

- Containerize application using Docker.
- Store container images in Amazon ECR.
- Deploy application containers.
- Connect application to RDS.
- Implement CI/CD pipeline.
- Add CloudWatch monitoring.
- Improve observability.

---

# Project Status

Current Version:

```
v0.3.1
```

Status:

```
Secure AWS Terraform Infrastructure Foundation Completed
```
