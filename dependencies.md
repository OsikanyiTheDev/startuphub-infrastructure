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

## 5. GitHub CLI (Required for CI/CD)

**Purpose:** Manage GitHub secrets and workflows from the command line

**Minimum Version:** 2.0.0

**Installation:**

### macOS (Homebrew)
```bash
brew install gh
```

### Ubuntu/Debian
```bash
sudo apt update
sudo apt install gh -y
```

### Windows
```powershell
choco install gh
```

**Verify Installation:**
```bash
gh --version
```

**Authentication:**
```bash
gh auth login
```

Follow the prompts:
- Choose **GitHub.com**
- Choose **HTTPS** or **SSH** (based on your Git setup)
- Choose **Login with a web browser**
- Copy the one-time code and authorize in browser

**Verify Authentication:**
```bash
gh auth status
```

---

## 6. AWS Session Manager Plugin (Required for EC2 Access)

**Purpose:** Connect to EC2 instances without SSH

**Installation:**

### macOS
```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/sessionmanager-bundle.zip" -o "sessionmanager-bundle.zip"
unzip sessionmanager-bundle.zip
sudo ./sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
```

### Ubuntu/Debian
```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb
```

### Windows
Download and run the MSI installer from AWS.

**Verify Installation:**
```bash
session-manager-plugin
```

**Connect to EC2 Instance:**
```bash
aws ssm start-session --target <instance-id>
```

---

## 7. Node.js (Optional)

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
- `AmazonS3FullAccess` (for Terraform state backend)
- `CloudWatchFullAccess` (for monitoring and alarms)
- `AmazonSNSFullAccess` (for alarm notifications)

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

############################
# GitHub Actions
############################
github_repository = "OsikanyiTheDev/startuphub-infrastructure"

############################
# SNS Alerts
############################
alert_email = "osikanyie@gmail.com"
```

**Note:** This file is gitignored to protect sensitive configuration.

---

## Deployment Steps

### Option 1: Automated CI/CD (Recommended)

#### Initial Setup (One-time)

1. **Clone Repository:**
```bash
git clone git@github.com:OsikanyiTheDev/startuphub-infrastructure.git
cd startuphub-infrastructure
```

2. **Configure AWS:**
```bash
aws configure
aws sts get-caller-identity
```

3. **Deploy Infrastructure (First Time Only):**
```bash
cd environments/dev
terraform init
terraform apply
```

This creates all resources with `desired_capacity = 0`.

4. **Build and Push Docker Image:**
```bash
cd ../..
chmod +x scripts/build-and-push.sh
./scripts/build-and-push.sh dev ./app latest
```

5. **Launch EC2 Instances:**
Edit `environments/dev/terraform.tfvars`:
```hcl
desired_capacity = 2
min_size         = 2
```

```bash
cd environments/dev
terraform apply
```

6. **Setup GitHub Secrets for CI/CD:**
```bash
cd ..
gh auth login
chmod +x scripts/set-github-secrets.sh
./scripts/set-github-secrets.sh
```

#### Daily Workflow (After Setup)

Simply push to main:
```bash
git add .
git commit -m "feat: update infrastructure"
git push origin main
```

The CI/CD pipeline automatically:
- ✅ Validates Terraform
- ✅ Builds Docker image
- ✅ Pushes to ECR
- ✅ Runs terraform plan
- ✅ Applies changes

---

### Option 2: Manual Deployment (Three-Phase)

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

### Verify Deployment

```bash
terraform output alb_dns_name
```

Visit the ALB URL in your browser (wait 5-7 minutes for instances to initialize).

### Verify Monitoring

**Check CloudWatch Logs:**
```bash
# View user-data logs
aws logs tail /aws/ec2/startuphub-dev/user-data --since 1h

# View Docker logs
aws logs tail /aws/ec2/startuphub-dev/docker --since 1h

# View system logs
aws logs tail /aws/ec2/startuphub-dev/system --since 1h
```

**Check CloudWatch Agent:**
```bash
# Connect to EC2 via SSM
aws ssm start-session --target <instance-id>

# Check agent status
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status

# Expected: status: running
```

**Check Dashboard:**
1. Go to AWS Console → CloudWatch → Dashboards
2. Open `startuphub-dev-dashboard`
3. Verify all 8 widgets show data (EC2 CPU, Memory, ALB metrics, RDS metrics)

**Confirm SNS Email:**
- Check email inbox for "AWS Notification - Subscription Confirmation"
- Click "Confirm subscription" to activate alarm notifications

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

### Database Connection Failed
- Verify RDS instance is available: `aws rds describe-db-instances`
- Check security group allows port 5432 from EC2
- Verify credentials in Secrets Manager
- Check user data logs: `sudo cat /var/log/user-data.log`

### GitHub Actions Workflow Fails
- Check workflow logs in GitHub Actions tab
- Verify `AWS_ROLE_ARN` secret is set correctly
- Ensure GitHub Actions has required permissions
- Check OIDC provider is configured

### Terraform Plan/Apply Hangs in CI/CD
- Ensure all 33 `TF_VAR_*` secrets are set in GitHub
- Run `./scripts/set-github-secrets.sh` to populate secrets
- Verify secrets match local `terraform.tfvars` values

---

## Cost Considerations

### Estimated Monthly Costs (us-east-1)

- **VPC + NAT Gateway:** ~$45
- **EC2 (2x t3.micro):** ~$15
- **RDS (db.t3.micro):** ~$15
- **ALB:** ~$16
- **ECR:** ~$1
- **Data Transfer:** ~$5
- **CloudWatch Monitoring:** ~$10-15
  - Logs (30-day retention): ~$3-5
  - Custom metrics (CloudWatch Agent): ~$3-5
  - Dashboard: Free (3 dashboards included)
  - Alarms: ~$0.10/alarm/month
  - SNS notifications: ~$0.50 for 100 notifications

**Total:** ~$107-112/month

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
- Check GitHub Actions documentation
