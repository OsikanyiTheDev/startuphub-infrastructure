# StartupHub AWS Infrastructure (Terraform)

## Overview

StartupHub Infrastructure is a production-style AWS cloud environment built using **Terraform Infrastructure as Code (IaC)**.

The goal of this project is to design, provision, and manage a secure, scalable, and highly available AWS architecture using Terraform modules.

The infrastructure follows AWS best practices by:

- Separating workloads into public and private networks
- Removing direct SSH access to EC2 instances
- Using AWS Systems Manager for secure instance management
- Implementing IAM least-privilege access
- Storing database credentials securely using AWS Secrets Manager
- Deploying resources using reusable Terraform modules

---

# Architecture Overview

```
                              Internet
                                  |
                                  |
                     Application Load Balancer
                                  |
                  --------------------------------
                  |                              |
            Public Subnet 1                Public Subnet 2
                  |
                  |
             Target Group
                  |
                  |
          Auto Scaling Group (EC2)
                  |
        -----------------------------
        |                           |
 Private Application Subnet 1   Private Application Subnet 2
        |
        |
     EC2 Instances
        |
        |
        |-----------------------------
        |                            |
 AWS Systems Manager          AWS Secrets Manager
        |                            |
        |                    RDS Database Credentials
        |
        |
 Private Database Subnets
        |
        |
 Amazon RDS PostgreSQL Database

```

---

# AWS Services Used

## Networking

The networking layer provides a secure multi-tier VPC architecture.

Services used:

- Amazon VPC
- Public Subnets
- Private Application Subnets
- Private Database Subnets
- Internet Gateway
- NAT Gateway
- Route Tables
- Elastic IP

Network design:

```
Public Layer
|
|-- Application Load Balancer

Private Application Layer
|
|-- EC2 Instances
|-- Auto Scaling Group

Private Database Layer
|
|-- PostgreSQL RDS Database

```

---

# Compute Layer

The compute layer runs the application workload.

Services used:

- Amazon EC2
- EC2 Launch Templates
- Auto Scaling Groups
- IAM Instance Profiles

Features:

- Multiple EC2 instances
- Automatic scaling
- Encrypted EBS volumes
- IMDSv2 enabled
- Monitoring enabled

---

# Load Balancing

The application uses an Application Load Balancer.

Architecture:

```
Users
 |
 |
Application Load Balancer
 |
 |
Target Group
 |
 |
EC2 Instances

```

Benefits:

- High availability
- Traffic distribution
- Health checks
- Easy scaling

---

# Database Layer

The database layer uses Amazon RDS PostgreSQL.

Features:

- PostgreSQL 16
- Private database subnets
- Encryption enabled
- Automated backups
- Database security group isolation
- No public accessibility

Database access flow:

```
EC2 Instance
      |
      |
Private Network
      |
      |
Amazon RDS PostgreSQL

```

Only EC2 instances are allowed to communicate with the database.

---

# Security Architecture

## Removal of SSH Access

Traditional cloud deployments often expose SSH access:

```
Developer
    |
    |
 SSH Port 22
    |
    |
 EC2 Instance

```

This project removes direct SSH access.

The new approach:

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

# IAM Security

The EC2 instances use an IAM Role instead of static credentials.

The EC2 role provides:

- AWS Systems Manager access
- Secure AWS service communication
- Controlled permissions

IAM follows the principle of:

```
Least Privilege Access

```

---

# Secrets Management

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
EC2 IAM Role
```

The EC2 role is allowed to retrieve only the required database secret.

Permission granted:

```
secretsmanager:GetSecretValue

```

The EC2 instance does not have permission to access unrelated secrets.

---

# Terraform Project Structure

```
startuphub-infrastructure/

│
├── environments/
│   │
│   └── dev/
│       │
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── outputs.tf
│
│
├── modules/
│   │
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── security/
│   │   ├── main.tf
│   │   ├── secrets.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── compute/
│   │   ├── main.tf
│   │   ├── iam.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── alb/
│   │
│   ├── autoscaling/
│   │
│   └── rds/
│
└── README.md

```

---

# Terraform Deployment

## Prerequisites

Install:

- Terraform
- AWS CLI

Configure AWS credentials:

```bash
aws configure
```

Verify AWS account:

```bash
aws sts get-caller-identity
```

---

# Initialize Terraform

Navigate to the environment:

```bash
cd environments/dev
```

Initialize Terraform:

```bash
terraform init
```

---

# Validate Configuration

Run:

```bash
terraform validate
```

---

# Review Infrastructure Changes

Generate execution plan:

```bash
terraform plan
```

Save plan:

```bash
terraform plan -out=tfplan
```

---

# Deploy Infrastructure

Apply the saved plan:

```bash
terraform apply tfplan
```

---

# View Outputs

Example:

```bash
terraform output
```

Available outputs include:

- VPC ID
- Subnet IDs
- Load Balancer DNS Name
- Launch Template ID
- Auto Scaling Group Name
- RDS Secret ARN

---

# Destroy Infrastructure

To remove all AWS resources:

```bash
terraform destroy
```

---

# Current Features

✅ Modular Terraform architecture  
✅ Custom AWS VPC design  
✅ Public and private subnet separation  
✅ NAT Gateway configuration  
✅ Application Load Balancer  
✅ EC2 Launch Template  
✅ Auto Scaling Group  
✅ IAM Role based EC2 access  
✅ AWS Systems Manager access  
✅ Secrets Manager integration  
✅ Private PostgreSQL RDS database  
✅ Security Group isolation  
✅ Encrypted storage  
✅ Infrastructure as Code approach  

---

# Future Improvements

Planned improvements:

- HTTPS with ACM certificates
- Route53 DNS integration
- CloudWatch monitoring and alarms
- Centralized logging
- Terraform remote backend using S3 and DynamoDB
- GitHub Actions CI/CD pipeline
- Container deployment using ECS/EKS
- AWS WAF integration
- Blue/Green deployments

---

# Skills Demonstrated

This project demonstrates practical experience with:

- Terraform
- AWS Cloud Architecture
- Infrastructure as Code
- Networking
- IAM Security
- EC2 Management
- Load Balancing
- Auto Scaling
- Database Security
- Secrets Management
- DevOps Practices

---

# Author

**Osikanyi Nana Yaw Essandoh**

Cloud Engineering / DevOps Portfolio Project