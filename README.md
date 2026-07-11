# StartupHub AWS Infrastructure (Terraform)

## Overview

StartupHub Infrastructure is a production-style AWS cloud environment built using **Terraform Infrastructure as Code (IaC)**.

This project provisions and manages a secure, scalable, and highly available AWS architecture using Terraform modules with containerized application deployment.

The infrastructure follows AWS best practices by:

- Separating workloads into public and private networks
- Deploying containerized applications via Amazon ECR
- Using AWS Systems Manager for secure instance management
- Implementing IAM least-privilege access
- Storing database credentials securely using AWS Secrets Manager
- Auto-scaling containerized workloads
- Deploying resources using reusable Terraform modules

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
├── app/                          # Application source code
│   ├── Dockerfile
│   ├── server.js
│   ├── package.json
│   └── .dockerignore
│
├── scripts/                      # Automation scripts
│   └── build-and-push.sh
│
├── environments/
│   └── dev/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
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
├── README.md
├── dependencies.md
└── .gitignore
```

---

## Deployment Workflow

### Phase 1: Infrastructure Setup

Navigate to the environment directory:

```bash
cd environments/dev
```

Initialize Terraform:

```bash
terraform init
```

Deploy infrastructure with EC2 scaled to 0:

```bash
terraform apply
```

This creates all resources except EC2 instances, avoiding race conditions.

---

### Phase 2: Build and Push Application

Return to project root:

```bash
cd ../..
```

Build and push the Docker image:

```bash
./scripts/build-and-push.sh dev ./app latest
```

---

### Phase 3: Launch EC2 Instances

Update `terraform.tfvars` to enable scaling:

```hcl
desired_capacity = 2
min_size         = 2
```

Apply changes:

```bash
terraform apply
```

EC2 instances will:

1. Launch and run user data script
2. Install Docker
3. Pull the container image from ECR
4. Start the application
5. Register with ALB target group
6. Pass health checks

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

---

## Future Improvements

Planned improvements:

- HTTPS with ACM certificates
- Route53 DNS integration
- CloudWatch monitoring and alarms
- Centralized logging
- Terraform remote backend using S3 and DynamoDB
- GitHub Actions CI/CD pipeline
- AWS WAF integration
- Blue/Green deployments
- Container orchestration with ECS/EKS

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

---

## Author

**Osikanyi Essandoh**
**OsikanyiTheDev**

Cloud Engineering / DevOps Portfolio Project

---

## Version History

- **v0.6.0**
- **v0.5.0** - Docker/ECR integration with containerized deployment
- **v0.4.0** - RDS PostgreSQL with Secrets Manager
- **v0.3.0** - Security hardening (IAM, SSM, encryption)
- **v0.2.0** - Load balancer and auto scaling
- **v0.1.0** - Initial VPC and networking setup
# Testing CI/CD - Sat Jul 11 08:58:32 AM GMT 2026
