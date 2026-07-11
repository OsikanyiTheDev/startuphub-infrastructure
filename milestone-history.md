# StartupHub Infrastructure - Milestone History

---

# v0.6.0 - CI/CD Pipeline with GitHub Actions (Current)

**Date:** July 2026

## Overview

Achieved full CI/CD automation with GitHub Actions, enabling zero-touch deployments. Every push to the `main` branch now automatically validates infrastructure, builds and pushes Docker images to ECR, and applies Terraform changes to AWS.

This milestone transforms the project from manual deployments to production-grade automated CI/CD pipelines with zero secrets in git.

---

## Major Achievements

### Full CI/CD Automation

Implemented a 4-stage GitHub Actions workflow:

```
git push → Validate → Build & Push → Plan → Apply
```

**Workflow Stages:**

1. **Validate Terraform**
   - Runs `terraform fmt -check -recursive`
   - Runs `terraform validate`
   - Catches syntax errors before deployment

2. **Build and Push Docker Image**
   - Authenticates to ECR via OIDC
   - Builds Docker image from `app/`
   - Tags as `latest`
   - Pushes to ECR repository

3. **Terraform Plan**
   - Generates `terraform.tfvars` from 32 GitHub Secrets
   - Runs `terraform plan`
   - Shows planned changes before apply

4. **Terraform Apply**
   - Automatically applies infrastructure changes
   - No manual approval required
   - Full audit trail in GitHub Actions

### OIDC Authentication

Eliminated AWS access keys entirely by implementing GitHub Actions OIDC:

```yaml
permissions:
  id-token: write
  contents: read
```

**Benefits:**
- No AWS credentials stored in GitHub
- Temporary credentials auto-rotate
- Scoped to specific repository
- Enhanced security posture

### Secrets Management with GitHub Secrets

All 32 infrastructure variables stored securely in GitHub Secrets:

```bash
# Automated setup script
./scripts/set-github-secrets.sh
```

**Secrets Include:**
- Project configuration (project_name, region, vpc_cidr)
- Network configuration (subnet CIDRs)
- EC2 configuration (ami_id, instance_type)
- ASG configuration (desired_capacity, min_size, max_size)
- RDS configuration (engine, version, credentials)
- ECR configuration (image_tag, scan_on_push)
- GitHub repository reference

**Security:**
- ✅ Zero secrets in git repository
- ✅ Encrypted at rest in GitHub
- ✅ Automatically injected during workflow runs
- ✅ Easy rotation via `gh secret set` command

### IAM Module for GitHub Actions

Created new IAM module (`modules/iam/`) to support CI/CD:

```
modules/iam/
├── main.tf        # OIDC provider + IAM role
├── variables.tf   # github_repository variable
└── outputs.tf     # github_actions_role_arn output
```

**IAM Role Permissions:**
- AmazonVPCFullAccess
- AmazonEC2FullAccess
- AmazonRDSFullAccess
- ElasticLoadBalancingFullAccess
- AutoScalingFullAccess
- AmazonEC2ContainerRegistryFullAccess
- IAMFullAccess
- SecretsManagerReadWrite
- AmazonS3FullAccess

### GitHub CLI Integration

Added automation scripts for GitHub CLI:

```bash
# Install GitHub CLI
sudo apt install gh -y

# Authenticate
gh auth login

# Push secrets
./scripts/set-github-secrets.sh
```

**Automation Script:** `scripts/set-github-secrets.sh`
- Automatically sets all 32 secrets from `terraform.tfvars`
- One command replaces 32 manual clicks
- Gitignored (contains sensitive values)

### Path-Based Triggers

Workflow only runs when relevant files change:

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'modules/**'
      - 'environments/dev/**'
      - 'app/**'
      - 'scripts/**'
      - '.github/workflows/**'
```

**Benefits:**
- Faster feedback (no wasted runs)
- Reduced GitHub Actions minutes
- Clear trigger conditions

---

## Workflow Configuration

### GitHub Actions Workflow

**File:** `.github/workflows/ci-cd.yml`

```yaml
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - terraform fmt -check -recursive
      - terraform init
      - terraform validate

  build-and-push:
    needs: validate
    steps:
      - aws-actions/configure-aws-credentials (OIDC)
      - aws-actions/amazon-ecr-login
      - docker build
      - docker push

  terraform-plan:
    needs: build-and-push
    steps:
      - Generate terraform.tfvars from secrets
      - terraform init
      - terraform plan

  terraform-apply:
    needs: terraform-plan
    steps:
      - Generate terraform.tfvars from secrets
      - terraform init
      - terraform apply -auto-approve
```

**Execution Time:** ~5-7 minutes per run

---

## Infrastructure Updates

### New Module: IAM

Added IAM module for GitHub Actions OIDC authentication:

```hcl
module "iam" {
  source              = "../../modules/iam"
  project_name        = var.project_name
  github_repository   = var.github_repository
}
```

**Resources Created:**
- `aws_iam_openid_connect_provider.github`
- `aws_iam_role.github_actions`
- `aws_iam_role_policy_attachment.*` (9 policies)

---

## Documentation Updates

### README.md

Added comprehensive CI/CD section:
- Automated deployment workflow diagram
- Secrets management explanation
- OIDC authentication details
- Disaster recovery process (20 minutes from zero)

### dependencies.md

Added new dependencies:
- GitHub CLI (gh) installation and authentication
- AWS Session Manager Plugin for EC2 access
- Updated deployment steps for CI/CD workflow

### milestone-history.md

Documented v0.6.0 achievements:
- Full CI/CD automation details
- OIDC authentication benefits
- Secrets management approach
- Lessons learned

---

## Validation Completed

✅ Terraform fmt clean
✅ Terraform validate successful
✅ GitHub Actions workflow runs successfully
✅ All 4 jobs complete (Validate, Build, Plan, Apply)
✅ OIDC authentication works (no AWS keys)
✅ 32 secrets stored in GitHub Secrets
✅ Docker image automatically built and pushed
✅ Infrastructure automatically applied
✅ Zero secrets in git repository
✅ All documentation updated

---

## Deployment Verification

### Check GitHub Actions Workflow

```bash
# Via GitHub CLI
gh run list

# Via browser
# https://github.com/OsikanyiTheDev/startuphub-infrastructure/actions
```

### Check Secrets

```bash
gh secret list
```

Expected: 32 `TF_VAR_*` secrets + `AWS_ROLE_ARN`

### Test Automatic Deployment

```bash
# Make a change
echo "# Test $(date)" >> README.md
git add README.md
git commit -m "test: trigger CI/CD"
git push origin main

# Watch workflow run
gh run watch
```

---

## Lessons Learned

### Secrets Management in CI/CD

**Challenge:** How to manage 32 variables without storing them in git?

**Solution:** GitHub Secrets + automated setup script

**Key Insights:**
- Never commit `terraform.tfvars` (gitignored)
- Use `gh secret set` for automation
- Store secrets as `TF_VAR_*` prefix
- One script to rule them all

### OIDC vs Access Keys

**Challenge:** AWS credentials in GitHub Secrets are a security risk

**Solution:** GitHub Actions OIDC (OpenID Connect)

**Key Insights:**
- OIDC provides temporary credentials
- No long-lived keys to manage
- Scoped to specific repository
- Industry best practice

### Workflow Trigger Conditions

**Challenge:** Workflow runs on every push, wasting time

**Solution:** Path-based triggers

**Key Insights:**
- Only run when relevant files change
- Use `paths:` filter in workflow
- Saves GitHub Actions minutes
- Faster feedback loop

### Terraform Plan Hanging

**Challenge:** `terraform plan` hangs for 3 hours in CI/CD

**Root Cause:** Missing `terraform.tfvars` causes interactive prompts

**Solution:** Generate `terraform.tfvars` from GitHub Secrets before running plan

**Key Insights:**
- Always generate tfvars in CI/CD
- Use `cat > terraform.tfvars <<EOF` heredoc
- Inject secrets at runtime
- Never commit tfvars

### Manual vs Automatic Apply

**Challenge:** Should `terraform apply` be manual or automatic?

**Decision:** Automatic for this project

**Rationale:**
- Dev environment, low risk
- Full audit trail in GitHub Actions
- Faster iteration
- Production would use manual approval

**For Production:**
- Add `environment: production` gate
- Require manual approval
- Use GitHub Environments

---

## Previous Versions

### v0.5.0 - Production-Ready Containerized Deployment

- Working container deployment with Docker
- ECR integration for image storage
- Port configuration fixed (80 → 3000)
- User data script validated
- Security group architecture documented
- Three-phase deployment working

### v0.4.0 - Docker & ECR Integration

- Added ECR module
- Created Docker application (Node.js + Express)
- Converted user_data.sh to user_data.tpl
- Added build-and-push.sh automation script
- Implemented two-phase deployment strategy
- **Status:** Integration complete but port configuration issue prevented successful deployment

### v0.3.1 - Secure Rebuild Validation

- Full destroy and rebuild cycle validated
- SSH access removed
- EC2 IAM Role with SSM
- Secrets Manager integration
- Private RDS deployment

### v0.3.0 - Security Hardening

- SSH removal
- EC2 IAM Role
- AWS Systems Manager access
- Encrypted EC2 storage
- IMDSv2 enforcement
- Private RDS deployment

### v0.2.0 - Compute and Application Layer

- Application Load Balancer
- EC2 Launch Template
- Auto Scaling Group
- Private EC2 deployment
- Security Groups

### v0.1.0 - Network Foundation

- Terraform project structure
- AWS VPC
- Public and private subnets
- Internet Gateway
- NAT Gateway
- Routing architecture

---

## Next Milestone

### v0.7.0 - Monitoring & Logging

Planned improvements:

- CloudWatch Agent installation on EC2
- CloudWatch Logs for Docker and application logs
- CPU and Memory alarms
- SNS notifications for alerts
- CloudWatch dashboards
- Log retention policies
- Automated log analysis

---

# Project Status

**Current Version:**

```
v0.6.0
```

**Status:**

```
Full CI/CD Automation
Zero-Touch Deployments
Production-Grade GitHub Actions Pipeline
```

**Architecture:**

```
git push → GitHub Actions → Validate → Build → Push → Plan → Apply → AWS
                                              ↓
                                          ECR Repository
                                              ↓
                                          EC2 Instances
                                              ↓
                                          RDS PostgreSQL
```

**Deployment Time:** 5-7 minutes (fully automated)

**Manual Steps:** Zero

**Secrets in Git:** Zero

---

**Date:** July 2026

## Overview

Achieved full production-ready containerized deployment with successful end-to-end integration of Docker, Amazon ECR, EC2, ALB, and PostgreSQL RDS.

This milestone validates that the entire infrastructure works correctly: from Terraform provisioning through container deployment to application serving via the ALB.

---

## Major Achievements

### Working Container Deployment

Successfully deployed a containerized Node.js application that:

- Pulls Docker images from Amazon ECR
- Connects to PostgreSQL RDS using credentials from AWS Secrets Manager
- Serves traffic via Application Load Balancer
- Auto-scales with ASG

### Port Configuration Fixed

**Problem:** ALB was configured to target port 80, but the application runs on port 3000.

**Solution:**
- Updated ALB target group to use port 3000
- Updated EC2 security group to allow port 3000 from ALB
- Health checks now pass successfully

### Security Group Architecture

```
Internet → ALB (Port 80)
    ↓
ALB Security Group
    ↓
EC2 Security Group (Port 3000 from ALB only)
    ↓
Docker Container (Port 3000)
```

### User Data Script Validation

The EC2 user data script successfully:

1. Installs Docker runtime
2. Installs AWS CLI v2
3. Authenticates with Amazon ECR using IAM role
4. Pulls the latest container image
5. Retrieves database credentials from Secrets Manager
6. Starts the container with environment variables
7. Container passes ALB health checks

**Verification:** Check `/var/log/user-data.log` on EC2 instances for full execution logs.

---

## Infrastructure Components

### Application Stack

```
Node.js + Express (Port 3000)
    ↓
PostgreSQL RDS (Port 5432)
    ↓
AWS Secrets Manager (Credentials)
```

### Deployment Pipeline

```
1. terraform apply (Phase 1: desired_capacity = 0)
   → Creates ECR, ALB, ASG, RDS, Security Groups
   
2. ./scripts/build-and-push.sh dev ./app latest
   → Builds Docker image
   → Pushes to ECR
   
3. Update terraform.tfvars (desired_capacity = 2)
   
4. terraform apply (Phase 2)
   → ASG launches EC2 instances
   → User data installs Docker
   → Pulls image from ECR
   → Starts container
   → Health checks pass
   → ALB routes traffic
```

### Network Architecture

```
Internet
    ↓
Application Load Balancer (Port 80)
    ↓
Target Group (Port 3000)
    ↓
Auto Scaling Group
    ↓
EC2 Instances (Private Subnets)
    ├── Docker Container (Port 3000)
    ├── IAM Role (ECR + Secrets Manager access)
    └── Security Group (Port 3000 from ALB)
    ↓
RDS PostgreSQL (Private DB Subnets)
    ↓
Secrets Manager (Database credentials)
```

---

## Configuration Updates

### ALB Target Group

```hcl
resource "aws_lb_target_group" "this" {
  name     = "${var.name}-tg"
  port     = 3000  # Changed from 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}
```

### EC2 Security Group

```hcl
resource "aws_security_group" "ec2" {
  name        = "${var.name}-ec2-sg"
  description = "Allows application traffic from ALB only"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from ALB"
    from_port   = 3000  # Changed from 80
    to_port     = 3000
    protocol    = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

---

## IAM Role Configuration

The EC2 IAM role now includes three managed policies:

```
EC2 IAM Role
├── AmazonSSMManagedInstanceCore
│   → Systems Manager access
│
├── AmazonEC2ContainerRegistryReadOnly
│   → Pull images from ECR
│
└── Custom Policy: secretsmanager:GetSecretValue
    → Retrieve database credentials (scoped to specific ARN)
```

**Security:** No hardcoded credentials anywhere. All authentication via IAM roles.

---

## Documentation Updates

### README.md

Completely rewritten to reflect v0.5.0 architecture:
- Container deployment workflow
- ECR integration details
- Three-phase deployment process
- Updated project structure
- New troubleshooting section

### dependencies.md

New file created with:
- Required tools (Terraform, AWS CLI, Docker, Git)
- Installation instructions for macOS, Ubuntu/Debian, Windows
- AWS configuration steps
- IAM permissions required
- terraform.tfvars template
- Deployment steps
- Troubleshooting guide
- Cost estimates

---

## Validation Completed

✅ Terraform fmt clean
✅ Terraform validate successful
✅ ECR repository created
✅ Docker image built and pushed
✅ EC2 instances launched
✅ Docker installed on instances
✅ Image pulled from ECR
✅ Container started successfully
✅ Database connection established
✅ ALB health checks passing
✅ Application serving traffic
✅ User data logs verified
✅ Security groups configured correctly
✅ Two-phase deployment working
✅ All documentation updated

---

## Deployment Verification

### Check EC2 Instances

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=startuphub-dev" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name}' \
  --output table
```

### Check Target Health

```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --query 'TargetHealthDescriptions[].{ID:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason}' \
  --output table
```

Expected output:
```
-------------------------------------------
|         DescribeTargetHealth            |
+-------------+-----------+---------------+
|      ID     |   State   |    Reason     |
+-------------+-----------+---------------+
| i-xxxxx     | healthy   |               |
| i-xxxxx     | healthy   |               |
+-------------+-----------+---------------+
```

### Check User Data Logs

SSH or SSM into an EC2 instance:

```bash
sudo cat /var/log/user-data.log
```

Expected output:
```
=== Starting EC2 initialization ===
ECR Repository: 360831508664.dkr.ecr.us-east-1.amazonaws.com/startuphub-dev-app
Image Tag: latest
RDS Endpoint: startuphub-dev-postgres.cklouigmijld.us-east-1.rds.amazonaws.com
...
Docker installed successfully
ECR authentication successful
Image pulled successfully
Database credentials retrieved
Container started successfully
=== EC2 initialization complete ===
```

### Verify Application

```bash
terraform output alb_dns_name
# Visit the URL in browser
```

Expected: Task Manager app with database connection status and CRUD interface.

---

## Lessons Learned

### Port Mismatch Debugging

**Symptom:** ALB returns 502 Bad Gateway

**Root Cause:** Target group configured for port 80, but application listens on port 3000

**Debugging Steps:**
1. Check target group configuration: `aws elbv2 describe-target-groups`
2. Check security group rules: `aws ec2 describe-security-groups`
3. Check container logs: `docker logs startuphub-app`
4. Check user data logs: `cat /var/log/user-data.log`

**Solution:** Update both ALB target group and EC2 security group to use port 3000.

### Two-Phase Deployment Benefits

The three-phase deployment strategy (infrastructure → build/push → scale up) prevents:
- Race conditions between ECR image availability and instance launch
- Wasted resources from failed instance launches
- Confusion about which phase failed

### User Data Logging

Adding comprehensive logging to user data script makes debugging much easier:

```bash
exec > >(tee /var/log/user-data.log) 2>&1
```

This captures all output for troubleshooting.

---

## Previous Versions

### v0.4.0 - Docker & ECR Integration

- Added ECR module
- Created Docker application (Node.js + Express)
- Converted user_data.sh to user_data.tpl
- Added build-and-push.sh automation script
- Implemented two-phase deployment strategy
- **Status:** Integration complete but port configuration issue prevented successful deployment

### v0.3.1 - Secure Rebuild Validation

- Full destroy and rebuild cycle validated
- SSH access removed
- EC2 IAM Role with SSM
- Secrets Manager integration
- Private RDS deployment

### v0.3.0 - Security Hardening

- SSH removal
- EC2 IAM Role
- AWS Systems Manager access
- Encrypted EC2 storage
- IMDSv2 enforcement
- Private RDS deployment

### v0.2.0 - Compute and Application Layer

- Application Load Balancer
- EC2 Launch Template
- Auto Scaling Group
- Private EC2 deployment
- Security Groups

### v0.1.0 - Network Foundation

- Terraform project structure
- AWS VPC
- Public and private subnets
- Internet Gateway
- NAT Gateway
- Routing architecture

---

## Next Milestone (from v0.5.0)

### v0.6.0 - CI/CD Pipeline

**Status:** ✅ **COMPLETED** - See v0.6.0 section above

- ✅ GitHub Actions workflow for automated deployment
- ✅ Automated Docker build and push on code merge
- ✅ OIDC authentication (no AWS access keys)
- ✅ Secrets management with GitHub Secrets
- ✅ Fully automated terraform apply

---

# Project Status

**Current Version:**

```
v0.6.0
```

**Status:**

```
Full CI/CD Automation
Zero-Touch Deployments
Production-Grade GitHub Actions Pipeline
```

**Architecture:**

```
git push → GitHub Actions → Validate → Build → Push → Plan → Apply → AWS
                                              ↓
                                          ECR Repository
                                              ↓
                                          EC2 Instances
                                              ↓
                                          RDS PostgreSQL
```

**Deployment Time:** 5-7 minutes (fully automated)

**Manual Steps:** Zero

**Secrets in Git:** Zero

---
