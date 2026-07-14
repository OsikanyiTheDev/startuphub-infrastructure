# Deployment Guide

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Phase 1: Provision Infrastructure](#phase-1-provision-infrastructure)
4. [Phase 2: Build and Push Docker Image](#phase-2-build-and-push-docker-image)
5. [Phase 3: Launch EC2 Instances](#phase-3-launch-ec2-instances)
6. [Setup CI/CD Pipeline](#setup-cicd-pipeline)
7. [Verification](#verification)
8. [Day-2 Operations](#day-2-operations)
9. [Scaling](#scaling)
10. [Updates and Maintenance](#updates-and-maintenance)
11. [Rollback Procedures](#rollback-procedures)
12. [Disaster Recovery](#disaster-recovery)

---

## Prerequisites

### Required Tools

Install these tools before starting:

#### 1. AWS CLI v2

**macOS:**
```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

**Ubuntu/Debian:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Windows:**
Download from: https://aws.amazon.com/cli/

**Verify:**
```bash
aws --version
# Expected: aws-cli/2.x.x
```

#### 2. Terraform

**macOS:**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Ubuntu/Debian:**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install terraform
```

**Windows:**
```powershell
choco install terraform
```

**Verify:**
```bash
terraform --version
# Expected: Terraform v1.x.x
```

#### 3. Docker

**macOS:**
Download Docker Desktop from https://www.docker.com/products/docker-desktop/

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER
# Log out and back in
```

**Windows:**
Download Docker Desktop from https://www.docker.com/products/docker-desktop/

**Verify:**
```bash
docker --version
# Expected: Docker version 24.x.x

docker ps
# Should run without errors
```

#### 4. Git

**All platforms:**
Download from https://git-scm.com/

**Verify:**
```bash
git --version
# Expected: git version 2.x.x
```

#### 5. GitHub CLI (for CI/CD setup)

**macOS:**
```bash
brew install gh
```

**Ubuntu/Debian:**
```bash
sudo apt install gh
```

**Windows:**
```powershell
choco install gh
```

**Verify:**
```bash
gh --version
# Expected: gh version 2.x.x
```

#### 6. AWS Session Manager Plugin (for EC2 access)

**macOS:**
```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/sessionmanager-bundle.zip" -o "sessionmanager-bundle.zip"
unzip sessionmanager-bundle.zip
sudo ./sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
```

**Ubuntu/Debian:**
```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb
```

**Verify:**
```bash
session-manager-plugin
# Should show version info
```

### AWS Account Setup

#### 1. Create AWS Account

If you don't have an AWS account:
1. Go to https://aws.amazon.com/
2. Click "Create an AWS Account"
3. Follow the registration process
4. Enable MFA on root account (critical!)

#### 2. Configure AWS Credentials

```bash
aws configure
```

Enter:
- **AWS Access Key ID:** Your access key
- **AWS Secret Access Key:** Your secret key
- **Default region name:** `us-east-1`
- **Default output format:** `json`

**Verify:**
```bash
aws sts get-caller-identity
# Should show your account ID and user ARN
```

#### 3. Required IAM Permissions

Your AWS user/role needs these permissions:

**For Development:**
- `AdministratorAccess` (easiest, not recommended for production)

**For Production (least privilege):**
- `AmazonVPCFullAccess`
- `AmazonEC2FullAccess`
- `AmazonRDSFullAccess`
- `ElasticLoadBalancingFullAccess`
- `AutoScalingFullAccess`
- `AmazonEC2ContainerRegistryFullAccess`
- `IAMFullAccess`
- `SecretsManagerReadWrite`
- `AmazonS3FullAccess`
- `CloudWatchFullAccess`
- `AmazonSNSFullAccess`
- `AWSWAFV2FullAccess`

#### 4. Enable Required AWS Services

Ensure these services are enabled in your AWS account:
- Amazon VPC
- Amazon EC2
- Amazon RDS
- Elastic Load Balancing
- Auto Scaling
- Amazon ECR
- AWS IAM
- AWS Secrets Manager
- Amazon S3
- Amazon CloudWatch
- Amazon SNS
- AWS WAF
- AWS Systems Manager

---

## Initial Setup

### 1. Clone Repository

```bash
git clone git@github.com:OsikanyiTheDev/startuphub-infrastructure.git
cd startuphub-infrastructure
```

### 2. Review Project Structure

```bash
ls -la
```

You should see:
```
├── app/                    # Docker application
├── environments/dev/       # Terraform configuration
├── modules/                # Reusable Terraform modules
├── scripts/                # Automation scripts
├── ARCHITECTURE.md         # Architecture documentation
├── DEPLOYMENT.md           # This file
├── TROUBLESHOOTING.md      # Troubleshooting guide
├── COST.md                 # Cost analysis
└── README.md               # Project overview
```

### 3. Initialize Terraform

```bash
cd environments/dev
terraform init
```

**Expected output:**
```
Initializing modules...
- alb in ../../modules/alb
- autoscaling in ../../modules/autoscaling
- cloudwatch-alarms in ../../modules/cloudwatch-alarms
- cloudwatch-dashboard in ../../modules/cloudwatch-dashboard
- cloudwatch-logs in ../../modules/cloudwatch-logs
- compute in ../../modules/compute
- ecr in ../../modules/ecr
- iam in ../../modules/iam
- networking in ../../modules/networking
- rds in ../../modules/rds
- security in ../../modules/security
- sns in ../../modules/sns
- waf in ../../modules/waf

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...
- Installed hashicorp/aws v5.x.x

Terraform has been successfully initialized!
```

### 4. Review Terraform Plan

```bash
terraform plan
```

This will show what resources will be created. **Don't apply yet** - we need to configure variables first.

### 5. Configure Variables

Edit `terraform.tfvars`:

```bash
nano terraform.tfvars
```

Update these values as needed:

```hcl
# Project Configuration
project_name = "startuphub-dev"
region       = "us-east-1"

# Network Configuration
vpc_cidr                   = "10.0.0.0/16"
public_subnet_1_cidr       = "10.0.1.0/24"
public_subnet_2_cidr       = "10.0.2.0/24"
private_subnet_1_cidr      = "10.0.11.0/24"
private_subnet_2_cidr      = "10.0.12.0/24"
private_db_subnet_1_cidr   = "10.0.21.0/24"
private_db_subnet_2_cidr   = "10.0.22.0/24"

# Security Group Configuration
alb_http_cidr  = ["0.0.0.0/0"]
alb_https_cidr = ["0.0.0.0/0"]

# EC2 Configuration
ami_id        = "ami-0c55b159cbfafe1f0"  # Update for your region
instance_type = "t3.micro"

# Auto Scaling Configuration
desired_capacity = 0  # Start with 0 for Phase 1
min_size         = 0
max_size         = 4

# ALB Configuration
enable_deletion_protection = false

# RDS Configuration
db_engine              = "postgres"
db_engine_version      = "16"
db_instance_class      = "db.t3.micro"
db_allocated_storage   = 20
db_name                = "startuphub"
db_username            = "startupadmin"
db_password            = "CHANGE_ME_STRONG_PASSWORD"  # Use a strong password!
db_multi_az            = false
db_publicly_accessible = false
db_deletion_protection = false

# ECR Configuration
ecr_repository_name          = "startuphub-dev-app"
ecr_image_tag_mutability     = "MUTABLE"
ecr_scan_on_push             = true
ecr_image_tag                = "latest"

# GitHub Configuration
github_repository = "OsikanyiTheDev/startuphub-infrastructure"

# Monitoring Configuration
alert_email  = "your-email@example.com"
waf_rate_limit = 2000
```

**Important Notes:**

1. **AMI ID:** Update for your region
   - us-east-1: `ami-0c55b159cbfafe1f0`
   - us-west-2: `ami-0efcece6bed39fd9f`
   - eu-west-1: `ami-0905a3c97561e0b69`
   - Find latest: `aws ec2 describe-images --owners amazon --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*" --query 'sort_by(Images, &CreationDate)[-1].ImageId'`

2. **Database Password:** Use a strong password (16+ characters, mixed case, numbers, symbols)

3. **Email:** Use an email you can access (for SNS alerts)

4. **GitHub Repository:** Update to your repository name

---

## Phase 1: Provision Infrastructure

**Goal:** Create all AWS resources except EC2 instances (to avoid the ECR image dependency issue).

### Step 1: Verify Configuration

```bash
terraform plan
```

Review the output. You should see resources being created:
- VPC and subnets
- Security groups
- ALB and target groups
- Launch template
- Auto Scaling Group (with 0 instances)
- RDS database
- ECR repository
- IAM roles and policies
- CloudWatch resources
- SNS topic
- WAF WebACL

### Step 2: Apply Infrastructure

```bash
terraform apply
```

Type `yes` when prompted.

**Expected output:**
```
Apply complete! Resources: 45 added, 0 changed, 0 destroyed.

Outputs:

alb_dns_name = "startuphub-dev-alb-1234567890.us-east-1.elb.amazonaws.com"
ecr_repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/startuphub-dev-app"
rds_endpoint = "startuphub-dev-postgres.cxxxxxxx.us-east-1.rds.amazonaws.com"
```

**Duration:** 10-15 minutes

**What's Created:**
- VPC with 6 subnets (2 public, 2 private app, 2 private db)
- Internet Gateway and NAT Gateway
- Route tables and associations
- 3 security groups (ALB, EC2, RDS)
- Application Load Balancer
- Target group and listener
- Launch template (with user data script)
- Auto Scaling Group (0 instances)
- RDS PostgreSQL instance
- ECR repository
- IAM role and instance profile
- CloudWatch log groups, alarms, dashboard
- SNS topic and email subscription
- WAF WebACL with 5 rule groups

### Step 3: Verify Resources

**Check VPC:**
```bash
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=startuphub-dev-vpc"
```

**Check ALB:**
```bash
aws elbv2 describe-load-balancers --names startuphub-dev-alb
```

**Check RDS:**
```bash
aws rds describe-db-instances --db-instance-identifier startuphub-dev-postgres
```

**Check ECR:**
```bash
aws ecr describe-repositories --repository-names startuphub-dev-app
```

**Check ASG:**
```bash
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names startuphub-dev-asg
```

### Step 4: Confirm SNS Subscription

**Check your email** for a message from AWS SNS:

**Subject:** `AWS Notification - Subscription Confirmation`

**Action:** Click the "Confirm subscription" link.

**Why:** Without confirmation, CloudWatch alarms won't send email notifications.

### Phase 1 Complete ✅

At this point:
- ✅ All infrastructure is provisioned
- ✅ ECR repository exists (but empty)
- ✅ RDS database is ready
- ✅ ALB is ready (but no healthy targets)
- ❌ No EC2 instances running (desired_capacity = 0)

---

## Phase 2: Build and Push Docker Image

**Goal:** Build the Docker image and push it to ECR so EC2 instances can pull it.

### Step 1: Navigate to Project Root

```bash
cd ../..
```

### Step 2: Make Build Script Executable

```bash
chmod +x scripts/build-and-push.sh
```

### Step 3: Build and Push Image

```bash
./scripts/build-and-push.sh
```

**Expected output:**
```
🚀 Building Docker image...
Sending build context to Docker daemon  1.234MB
Step 1/8 : FROM node:18-alpine
 ---> a1b2c3d4e5f6
Step 2/8 : WORKDIR /app
 ---> Using cache
 ---> a1b2c3d4e5f7
...
Step 8/8 : CMD ["node", "server.js"]
 ---> Using cache
 ---> a1b2c3d4e5f8
Successfully built a1b2c3d4e5f9
Successfully tagged 123456789012.dkr.ecr.us-east-1.amazonaws.com/startuphub-dev-app:latest

📤 Pushing image to ECR...
The push refers to repository [123456789012.dkr.ecr.us-east-1.amazonaws.com/startuphub-dev-app]
a1b2c3d4e5f6: Pushed
b2c3d4e5f6a1: Pushed
...
latest: digest: sha256:abcdef1234567890... size: 1234

✅ Image pushed successfully!
```

**Duration:** 2-5 minutes

### Step 4: Verify Image in ECR

```bash
aws ecr list-images --repository-name startuphub-dev-app
```

**Expected output:**
```json
{
    "imageIds": [
        {
            "imageDigest": "sha256:abcdef1234567890...",
            "imageTag": "latest"
        }
    ]
}
```

### Step 5: Test Image Locally (Optional)

```bash
# Pull the image
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

docker pull 123456789012.dkr.ecr.us-east-1.amazonaws.com/startuphub-dev-app:latest

# Run the container
docker run -d \
  --name startuphub-test \
  -p 3000:3000 \
  -e DB_HOST=your-rds-endpoint \
  -e DB_PORT=5432 \
  -e DB_NAME=startuphub \
  -e DB_USER=startupadmin \
  -e DB_PASSWORD=your-password \
  123456789012.dkr.ecr.us-east-1.amazonaws.com/startuphub-dev-app:latest

# Test the application
curl http://localhost:3000/
# Expected: {"status":"ok","message":"StartupHub API is running"}

# Clean up
docker stop startuphub-test
docker rm startuphub-test
```

### Phase 2 Complete ✅

At this point:
- ✅ All infrastructure is provisioned
- ✅ Docker image is built and pushed to ECR
- ✅ ECR repository contains the image
- ✅ RDS database is ready
- ✅ ALB is ready (but no healthy targets)
- ❌ No EC2 instances running (desired_capacity = 0)

---

## Phase 3: Launch EC2 Instances

**Goal:** Launch EC2 instances that will pull the Docker image from ECR and serve the application.

### Step 1: Update Desired Capacity

Edit `environments/dev/terraform.tfvars`:

```bash
nano environments/dev/terraform.tfvars
```

Change:
```hcl
# Auto Scaling Configuration
desired_capacity = 2  # Changed from 0 to 2
min_size         = 2  # Changed from 0 to 2
max_size         = 4
```

### Step 2: Apply Changes

```bash
terraform apply
```

Type `yes` when prompted.

**Expected output:**
```
module.autoscaling.aws_autoscaling_group.this: Modifying... [id=startuphub-dev-asg]
module.autoscaling.aws_autoscaling_group.this: Modifications complete after 2s

Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

### Step 3: Monitor Instance Launch

```bash
watch -n 5 'aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names startuphub-dev-asg \
  --query "AutoScalingGroups[0].Instances[*].{InstanceId:InstanceId,State:LifecycleState,Health:HealthStatus}" \
  --output table'
```

**Expected progression:**
```
# After 30 seconds:
-----------------------------------------------------
|                 DescribeAutoScalingGroups            |
+----------------------+--------------+---------------+
|      Health          | InstanceId   |   State       |
+----------------------+--------------+---------------+
|      HEALTHY         |  i-abc123    |  InService    |
|      HEALTHY         |  i-def456    |  InService    |
+----------------------+--------------+---------------+
```

**Duration:** 5-10 minutes (Docker installation and image pull)

### Step 4: Check Target Health

```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --query "TargetHealthDescriptions[*].{Instance:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason}" \
  --output table
```

**Expected output:**
```
-------------------------------------------------------
|              DescribeTargetHealth                    |
+-------------------+--------------+------------------+
|      Instance     |    State     |     Reason       |
+-------------------+--------------+------------------+
|  i-abc123         |  healthy     |                  |
|  i-def456         |  healthy     |                  |
+-------------------+--------------+------------------+
```

### Step 5: Test Application

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

echo "Application URL: http://${ALB_DNS}"

# Test health endpoint
curl http://${ALB_DNS}/
# Expected: {"status":"ok","message":"StartupHub API is running"}

# Test API endpoint
curl http://${ALB_DNS}/api/tasks
# Expected: {"tasks":[],"total":0}
```

### Step 6: Access Application in Browser

Open your browser and navigate to:
```
http://startuphub-dev-alb-1234567890.us-east-1.elb.amazonaws.com
```

You should see the StartupHub application UI.

### Phase 3 Complete ✅

**Deployment Complete! 🎉**

At this point:
- ✅ All infrastructure is provisioned
- ✅ Docker image is built and pushed to ECR
- ✅ 2 EC2 instances are running
- ✅ Containers are running and healthy
- ✅ ALB is routing traffic to healthy instances
- ✅ Application is accessible via ALB DNS

---

## Setup CI/CD Pipeline

**Goal:** Configure GitHub Actions to automatically deploy changes.

### Step 1: Install and Authenticate GitHub CLI

```bash
gh auth login
```

Follow the prompts:
- **Account:** GitHub.com
- **Protocol:** HTTPS
- **Authentication:** Login with browser
- **Copy code:** [Copy the one-time code]
- **Browser:** Paste code and authorize

### Step 2: Make Secrets Script Executable

```bash
chmod +x scripts/set-github-secrets.sh
```

### Step 3: Set GitHub Secrets

```bash
./scripts/set-github-secrets.sh
```

**Expected output:**
```
🔐 Setting GitHub secrets...

✅ AWS_ROLE_ARN
✅ TF_VAR_project_name
✅ TF_VAR_region
...
✅ TF_VAR_alert_email
✅ TF_VAR_waf_rate_limit

✅ Done! All 36 secrets have been set.
```

### Step 4: Verify Secrets in GitHub

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. You should see 36 secrets listed

### Step 5: Test CI/CD Pipeline

Make a small change and push:

```bash
echo "# Test CI/CD - $(date)" >> README.md
git add README.md
git commit -m "test: trigger CI/CD pipeline"
git push origin main
```

### Step 6: Monitor Workflow

1. Go to your GitHub repository
2. Click **Actions** tab
3. You should see the workflow running

**Expected jobs:**
1. ✅ Validate Terraform
2. ✅ Build and Push Docker Image
3. ✅ Terraform Plan
4. ✅ Terraform Apply

**Duration:** 5-7 minutes

### CI/CD Setup Complete ✅

At this point:
- ✅ All infrastructure is deployed
- ✅ Application is running
- ✅ CI/CD pipeline is configured
- ✅ Future changes will be deployed automatically

---

## Verification

### Health Checks

#### 1. Application Health

```bash
ALB_DNS=$(terraform output -raw alb_dns_name)

# Health check endpoint
curl -s http://${ALB_DNS}/ | jq
# Expected: {"status":"ok","message":"StartupHub API is running"}

# API endpoint
curl -s http://${ALB_DNS}/api/tasks | jq
# Expected: {"tasks":[],"total":0}

# HTTP status code
curl -I http://${ALB_DNS}/
# Expected: HTTP/1.1 200 OK
```

#### 2. Infrastructure Health

```bash
# EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=startuphub-dev-*" \
  --query "Reservations[*].Instances[*].{ID:InstanceId,State:State.Name,Status:StatusCheckFailed}" \
  --output table

# Expected: All instances running with status 0

# Target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --query "TargetHealthDescriptions[*].{ID:Target.Id,State:TargetHealth.State}" \
  --output table

# Expected: All targets healthy

# RDS status
aws rds describe-db-instances \
  --db-instance-identifier startuphub-dev-postgres \
  --query "DBInstances[0].{Status:DBInstanceStatus,Engine:Engine,MultiAZ:MultiAZ}" \
  --output table

# Expected: Status = available

# ASG status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names startuphub-dev-asg \
  --query "AutoScalingGroups[0].{Desired:DesiredCapacity,Min:MinSize,Max:MaxSize,Instances:length(Instances)}" \
  --output table

# Expected: Desired = 2, Min = 2, Max = 4, Instances = 2
```

#### 3. Monitoring Health

```bash
# CloudWatch alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix startuphub-dev \
  --query "MetricAlarms[*].{Name:AlarmName,State:StateValue}" \
  --output table

# Expected: All alarms in OK state

# Recent logs
aws logs tail /aws/ec2/startuphub-dev/system --since 1h

# Expected: Recent log entries
```

### Performance Tests

#### 1. Response Time

```bash
# Single request
time curl -s http://${ALB_DNS}/ > /dev/null

# Expected: < 1 second

# Multiple requests
for i in {1..10}; do
  curl -s -o /dev/null -w "%{time_total}\n" http://${ALB_DNS}/
done

# Expected: Average < 0.5 seconds
```

#### 2. Load Test (Optional)

Install Apache Bench:
```bash
# macOS
brew install httpd

# Ubuntu
sudo apt install apache2-utils
```

Run load test:
```bash
ab -n 1000 -c 10 http://${ALB_DNS}/

# Expected:
# - Requests per second: > 100
# - Time per request: < 100ms
# - Failed requests: 0
```

---

## Day-2 Operations

### Common Tasks

#### 1. View Application Logs

```bash
# System logs
aws logs tail /aws/ec2/startuphub-dev/system --since 1h

# User data logs (EC2 initialization)
aws logs tail /aws/ec2/startuphub-dev/user-data --since 24h

# Docker logs (container stdout)
aws logs tail /aws/ec2/startuphub-dev/docker --since 1h

# Filter logs
aws logs filter-log-events \
  --log-group-name /aws/ec2/startuphub-dev/system \
  --filter-pattern "ERROR" \
  --start-time $(date -u -d '1 hour ago' +%s)000
```

#### 2. Connect to EC2 Instance

```bash
# List instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=startuphub-dev-*" \
  --query "Reservations[*].Instances[*].{ID:InstanceId,Name:Tags[?Key=='Name']|[0].Value}" \
  --output table

# Connect via SSM
aws ssm start-session --target i-0123456789abcdef0

# Once connected:
sudo docker ps
sudo docker logs <container-id>
sudo docker exec -it <container-id> sh
```

#### 3. Check Database

```bash
# Get RDS endpoint
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)

# Connect via SSM (from EC2 instance)
psql -h ${RDS_ENDPOINT} -U startupadmin -d startuphub

# Once connected:
\dt              # List tables
SELECT * FROM tasks LIMIT 10;
\q               # Quit
```

#### 4. View Metrics

```bash
# CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=startuphub-dev-asg \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --output table

# Memory utilization (custom metric)
aws cloudwatch get-metric-statistics \
  --namespace CWAgent \
  --metric-name MemoryUsedPercent \
  --dimensions Name=AutoScalingGroupName,Value=startuphub-dev-asg \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --output table
```

#### 5. Test WAF Protection

```bash
# Test SQL injection blocking
curl -I "http://${ALB_DNS}/?id=1' OR '1'='1"
# Expected: HTTP/1.1 403 Forbidden

# Test XSS blocking
curl -I "http://${ALB_DNS}/?q=<script>alert(1)</script>"
# Expected: HTTP/1.1 403 Forbidden

# View blocked requests
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

## Scaling

### Manual Scaling

#### 1. Scale Up (Add Instances)

```bash
# Update terraform.tfvars
nano environments/dev/terraform.tfvars

# Change:
desired_capacity = 4
min_size         = 4

# Apply
terraform apply
```

#### 2. Scale Down (Remove Instances)

```bash
# Update terraform.tfvars
nano environments/dev/terraform.tfvars

# Change:
desired_capacity = 2
min_size         = 2

# Apply
terraform apply
```

#### 3. Scale to Zero (Save Costs)

```bash
# Update terraform.tfvars
nano environments/dev/terraform.tfvars

# Change:
desired_capacity = 0
min_size         = 0

# Apply
terraform apply
```

**Note:** This stops all EC2 instances but keeps other resources running.

### Auto Scaling (Future Enhancement)

To enable auto scaling, add scaling policies:

```hcl
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "startuphub-dev-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "startuphub-dev-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}
```

---

## Updates and Maintenance

### Update Application Code

#### 1. Make Changes

```bash
cd app
nano server.js
# Make your changes
```

#### 2. Commit and Push

```bash
git add app/server.js
git commit -m "feat: add new feature"
git push origin main
```

#### 3. Monitor Deployment

```bash
# Watch CI/CD pipeline
gh run watch

# Or check in browser:
# https://github.com/OsikanyiTheDev/startuphub-infrastructure/actions
```

**Duration:** 5-7 minutes

### Update Infrastructure

#### 1. Make Changes

```bash
cd environments/dev
nano main.tf
# Make your changes
```

#### 2. Review Plan

```bash
terraform plan
```

**Review carefully** - understand what will change.

#### 3. Apply Changes

```bash
terraform apply
```

#### 4. Verify

```bash
terraform output
# Test application
```

### Update AMI

#### 1. Find Latest AMI

```bash
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*" \
  --query 'sort_by(Images, &CreationDate)[-1].{ID:ImageId,Date:CreationDate}' \
  --output table
```

#### 2. Update Variable

```bash
nano terraform.tfvars

# Change:
ami_id = "ami-NEW_AMI_ID"
```

#### 3. Apply

```bash
terraform apply
```

**Note:** This will trigger a rolling update of EC2 instances.

---

## Rollback Procedures

### Rollback Application

#### 1. Find Previous Image

```bash
aws ecr list-images --repository-name startuphub-dev-app

# Note the digest of the previous image
```

#### 2. Update Tag

```bash
# Get previous image digest
PREV_DIGEST="sha256:abcdef1234567890..."

# Tag it as latest
aws ecr batch-delete-image \
  --repository-name startuphub-dev-app \
  --image-ids imageTag=latest

aws ecr put-image \
  --repository-name startuphub-dev-app \
  --image-tag latest \
  --image-manifest $(aws ecr get-download-url-for-layer \
    --repository-name startuphub-dev-app \
    --layer-digest ${PREV_DIGEST})
```

#### 3. Restart Containers

```bash
# Force ASG to replace instances
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name startuphub-dev-asg \
  --preferences '{"MinHealthyPercentage": 100}'
```

### Rollback Infrastructure

#### 1. Check State History

```bash
terraform state list
```

#### 2. Revert to Previous State

```bash
# If you have state backups:
terraform state pull > current.tfstate
terraform state pull -version=1 > previous.tfstate
terraform state push previous.tfstate
```

#### 3. Or Use Git History

```bash
git log --oneline environments/dev/

# Checkout previous version
git checkout <commit-hash> -- environments/dev/

# Apply
terraform apply
```

---

## Disaster Recovery

### Complete Infrastructure Loss

#### 1. Clone Repository

```bash
git clone git@github.com:OsikanyiTheDev/startuphub-infrastructure.git
cd startuphub-infrastructure
```

#### 2. Configure AWS

```bash
aws configure
```

#### 3. Initialize Terraform

```bash
cd environments/dev
terraform init
```

#### 4. Deploy (All 3 Phases)

```bash
# Phase 1: Infrastructure
terraform apply

# Phase 2: Docker image
cd ../..
./scripts/build-and-push.sh

# Phase 3: EC2 instances
cd environments/dev
# Update desired_capacity = 2
terraform apply
```

**Duration:** 30-60 minutes

### Database Recovery

#### 1. Check Backups

```bash
aws rds describe-db-snapshots \
  --db-instance-identifier startuphub-dev-postgres \
  --query "DBSnapshots[*].{ID:DBSnapshotIdentifier,Time:SnapshotCreateTime}" \
  --output table
```

#### 2. Restore from Snapshot

```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier startuphub-dev-postgres \
  --target-db-instance-identifier startuphub-dev-postgres-restored \
  --restore-time "2024-01-15T10:00:00Z"
```

#### 3. Update Configuration

```bash
# Get new RDS endpoint
aws rds describe-db-instances \
  --db-instance-identifier startuphub-dev-postgres-restored \
  --query "DBInstances[0].Endpoint.Address" \
  --output text

# Update terraform.tfvars or Secrets Manager
```

### Data Loss Prevention

#### Best Practices:

1. **Enable RDS Automated Backups**
   ```bash
   aws rds modify-db-instance \
     --db-instance-identifier startuphub-dev-postgres \
     --backup-retention-period 7
   ```

2. **Enable S3 Versioning** (for Terraform state)
   ```bash
   aws s3api put-bucket-versioning \
     --bucket startuphub-terraform-state \
     --versioning-configuration Status=Enabled
   ```

3. **Regular Backups**
   ```bash
   # Database backup
   aws rds create-db-snapshot \
     --db-instance-identifier startuphub-dev-postgres \
     --db-snapshot-identifier manual-backup-$(date +%Y%m%d)
   ```

4. **Test Recovery**
   - Regularly test backup restoration
   - Document recovery procedures
   - Keep recovery time objective (RTO) < 1 hour

---

## Conclusion

### Deployment Summary

✅ **Phase 1:** Infrastructure provisioned
✅ **Phase 2:** Docker image pushed to ECR
✅ **Phase 3:** EC2 instances running and healthy
✅ **CI/CD:** GitHub Actions configured
✅ **Monitoring:** CloudWatch alerts and dashboard
✅ **Security:** WAF, IAM, and encryption enabled

### Next Steps

1. **Test the application** thoroughly
2. **Set up custom domain** (Route53 + ACM)
3. **Enable HTTPS** (ALB HTTPS listener)
4. **Configure auto scaling** policies
5. **Set up CI/CD** for multiple environments
6. **Implement blue/green** deployments

### Support

- **Architecture:** See `ARCHITECTURE.md`
- **Troubleshooting:** See `TROUBLESHOOTING.md`
- **Costs:** See `COST.md`
- **Milestones:** See `milestone-history.md`

### Maintenance Schedule

- **Daily:** Check CloudWatch alarms and logs
- **Weekly:** Review costs and performance metrics
- **Monthly:** Update AMIs and dependencies
- **Quarterly:** Test disaster recovery procedures
- **Yearly:** Review and update security policies

---

**Congratulations! Your production-ready infrastructure is live! 🎉**
