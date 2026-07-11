# Dependencies & Setup Guide

## Required Tools

Before deploying StartupHub infrastructure, ensure you have the following tools installed and configured.

---

## 1. Terraform

**Purpose:** Infrastructure as Code provisioning tool

**Minimum Version:** 1.5.0

**Installation:**

### macOS (Homebrew)
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

### Ubuntu/Debian
```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common

wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install terraform
```

### Windows
```powershell
choco install terraform
```

**Verify Installation:**
```bash
terraform --version
```

---

## 2. AWS CLI

**Purpose:** Command-line interface for AWS services

**Minimum Version:** 2.0.0

**Installation:**

### macOS
```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

### Ubuntu/Debian
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Windows
Download and run the MSI installer from AWS.

**Verify Installation:**
```bash
aws --version
```

---

## 3. Docker

**Purpose:** Container runtime for building and pushing images locally

**Minimum Version:** 20.10.0

**Installation:**

### macOS
Download Docker Desktop from docker.com

### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER
```

### Windows
Download Docker Desktop from docker.com

**Verify Installation:**
```bash
docker --version
docker ps
```

---

## 4. Git

**Purpose:** Version control

**Minimum Version:** 2.20.0

**Installation:**

### macOS
```bash
brew install git
```

### Ubuntu/Debian
```bash
sudo apt-get install git
```

### Windows
Download from git-scm.com

**Verify Installation:**
```bash
git --version
```

---

## 5. Node.js (Optional)

**Purpose:** Local development and testing of the application

**Minimum Version:** 18.0.0

**Installation:**

### Using nvm (Recommended)
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 18
nvm use 18
```

**Verify Installation:**
```bash
node --version
npm --version
```

---

## AWS Configuration

### 1. AWS Account

You need an AWS account with appropriate permissions to create:

- VPC and networking resources
- EC2 instances
- RDS databases
- Application Load Balancers
- Auto Scaling Groups
- ECR repositories
- IAM roles and policies
- Security groups

### 2. IAM Permissions

The IAM user/role used for deployment needs the following managed policies:

- `AmazonVPCFullAccess`
- `AmazonEC2FullAccess`
- `AmazonRDSFullAccess`
- `ElasticLoadBalancingFullAccess`
- `AutoScalingFullAccess`
- `AmazonEC2ContainerRegistryFullAccess`
- `IAMFullAccess`
- `SecretsManagerReadWrite`

Or use `AdministratorAccess` for initial testing (not recommended for production).

### 3. Configure AWS CLI

```bash
aws configure
```

Enter your credentials:
- AWS Access Key ID
- AWS Secret Access Key
- Default region name (e.g., `us-east-1`)
- Default output format (e.g., `json`)

**Verify Configuration:**
```bash
aws sts get-caller-identity
```

---

## Environment Configuration

### terraform.tfvars

Create a `terraform.tfvars` file in `environments/dev/`:

```hcl
############################
# Project
############################
project_name = "startuphub-dev"
environment  = "dev"

############################
# Region
############################
aws_region = "us-east-1"

############################
# VPC
############################
vpc_cidr = "10.0.0.0/16"

############################
# Subnets
############################
public_subnet_1_cidr      = "10.0.1.0/24"
public_subnet_2_cidr      = "10.0.2.0/24"
private_subnet_1_cidr     = "10.0.11.0/24"
private_subnet_2_cidr     = "10.0.12.0/24"
private_db_subnet_1_cidr  = "10.0.21.0/24"
private_db_subnet_2_cidr  = "10.0.22.0/24"

############################
# ALB
############################
alb_http_cidr  = ["0.0.0.0/0"]
alb_https_cidr = ["0.0.0.0/0"]

############################
# EC2
############################
ami_id        = "ami-0d28727121d5d4a3c"  # Ubuntu 22.04 us-east-1
instance_type = "t3.micro"

############################
# Auto Scaling
############################
desired_capacity = 0
min_size         = 0
max_size         = 4

############################
# RDS
############################
db_engine            = "postgres"
db_engine_version    = "16"
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_name              = "startuphub"
db_username          = "startupadmin"
db_multi_az          = false
db_publicly_accessible = false
db_deletion_protection = false

############################
# ECR
############################
ecr_image_tag_mutability = "MUTABLE"
ecr_scan_on_push         = true
ecr_image_tag            = "latest"
```

**Note:** This file is gitignored to protect sensitive configuration.

---

## Deployment Steps

### Step 1: Clone Repository

```bash
git clone https://github.com/OsikanyiTheDev/startuphub-infrastructure.git
cd startuphub-infrastructure
```

### Step 2: Initialize Terraform

```bash
cd environments/dev
terraform init
```

### Step 3: Validate Configuration

```bash
terraform validate
terraform plan
```

### Step 4: Deploy Infrastructure (Phase 1)

```bash
terraform apply
```

This creates all resources with EC2 instances scaled to 0.

### Step 5: Build and Push Docker Image (Phase 2)

```bash
cd ../..
chmod +x scripts/build-and-push.sh
./scripts/build-and-push.sh dev ./app latest
```

### Step 6: Launch EC2 Instances (Phase 3)

Edit `environments/dev/terraform.tfvars`:
```hcl
desired_capacity = 2
min_size         = 2
```

Apply changes:
```bash
cd environments/dev
terraform apply
```

### Step 7: Verify Deployment

```bash
terraform output alb_dns_name
```

Visit the ALB URL in your browser (wait 5-7 minutes for instances to initialize).

---

## Troubleshooting

### Terraform Init Fails
- Ensure AWS credentials are configured
- Check internet connectivity
- Verify Terraform version compatibility

### Docker Build Fails
- Ensure Docker daemon is running
- Check disk space
- Verify Dockerfile syntax

### EC2 Instances Not Healthy
- Check security group rules (port 3000 from ALB)
- Verify user data script executed: `/var/log/user-data.log`
- Check Docker container logs: `docker logs startuphub-app`

### ALB Returns 502
- Wait 5-7 minutes for container to start
- Verify target group port is 3000
- Check security group allows port 3000 from ALB

---

## Cost Considerations

### Estimated Monthly Costs (us-east-1)

- **VPC + NAT Gateway:** ~$45
- **EC2 (2x t3.micro):** ~$15
- **RDS (db.t3.micro):** ~$15
- **ALB:** ~$16
- **ECR:** ~$1
- **Data Transfer:** ~$5

**Total:** ~$97/month

**Cost Optimization:**
- Set `desired_capacity = 0` when not in use
- Use spot instances for non-critical workloads
- Right-size EC2 and RDS instances
- Enable RDS instance auto-stop

---

## Support

For issues or questions:
- Open an issue on GitHub
- Review AWS documentation
- Check Terraform documentation
