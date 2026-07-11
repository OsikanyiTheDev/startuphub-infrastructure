# StartupHub Infrastructure - Milestone History

---

# v0.5.0 - Production-Ready Containerized Deployment (Current)

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

## Next Milestone

### v0.6.0 - CI/CD Pipeline & Observability

Planned improvements:

- GitHub Actions workflow for automated deployment
- Automated Docker build and push on code merge
- CloudWatch monitoring and alerting
- Centralized logging with CloudWatch Logs
- Custom metrics and dashboards
- Blue/Green deployment strategy
- Automated testing integration

---

# Project Status

**Current Version:**

```
v0.5.0
```

**Status:**

```
Production-Ready Containerized Deployment
End-to-End Integration Verified
Application Successfully Serving Traffic
```

**Architecture:**

```
Terraform → ECR → EC2/Docker → ALB → Internet
              ↓
          RDS PostgreSQL (via Secrets Manager)
```

---
