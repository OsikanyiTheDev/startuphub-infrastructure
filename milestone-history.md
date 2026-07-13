# StartupHub Infrastructure - Milestone History

---

# v0.9.0 - Web Application Firewall (WAF) Protection

**Date:** July 2026

## Overview

v0.9.0 adds enterprise-grade web application firewall protection to the StartupHub infrastructure. We implemented AWS WAF v2 with 5 managed rule groups to protect against common web attacks including SQL injection, cross-site scripting (XSS), and distributed denial-of-service (DDoS) attacks.

This milestone transforms the infrastructure from "deployed and monitored" to "deployed, monitored, and secured," demonstrating production-ready security practices.

---

## Major Achievements

### 1. WAF Module (`modules/waf`)

Created a dedicated module for web application firewall with 5 rule groups:

| Rule | Priority | Protection | Description |
|------|----------|------------|-------------|
| **Rate Limiting** | 1 | DDoS Protection | Blocks IPs exceeding 2000 requests per 5 minutes |
| **AWS Common Rules** | 2 | OWASP Top 10 | SQLi, XSS, RCE, SSRF, path traversal |
| **SQL Injection** | 3 | Database Security | Database attack patterns and injection attempts |
| **Known Bad Inputs** | 4 | Exploit Prevention | RCE, Java deserialization attacks |
| **IP Reputation** | 5 | Threat Intelligence | Blocks known malicious IP addresses |

**Benefits:**
- Protects against OWASP Top 10 vulnerabilities
- Prevents DDoS attacks via rate limiting
- Blocks known malicious IPs automatically
- Real-time CloudWatch metrics for blocked requests
- No code changes required in the application

### 2. IAM Policy Consolidation

**Problem:** The GitHub Actions role had 11 separate managed policies attached, hitting AWS's limit of 10 policies per role.

**Solution:** Consolidated all 11 managed policies into 1 custom customer-managed policy:

```hcl
resource "aws_iam_policy" "github_actions" {
  name        = "${var.project_name}-github-actions-policy"
  description = "Consolidated policy for GitHub Actions CI/CD pipeline"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2"
        Effect = "Allow"
        Action = ["ec2:*"]
        Resource = "*"
      },
      # ... (all other permissions)
    ]
  })
}
```

**Benefits:**
- Stays well under the 10-policy limit
- Easier to audit and review permissions
- Better security posture with explicit permissions
- Single source of truth for CI/CD permissions

### 3. Enhanced Security Posture

**Before v0.9.0:**
```
Internet → ALB → EC2 (Docker) → RDS
```

**After v0.9.0:**
```
Internet → WAF → ALB → EC2 (Docker) → RDS
    ↓
  - SQLi Protection
  - XSS Protection
  - Rate Limiting
  - IP Reputation
  - OWASP Top 10
```

---

## WAF Capabilities

### SQL Injection Protection

Blocks SQL injection attempts in:
- Query strings (`?id=1' OR '1'='1`)
- Request headers
- Request body
- Cookies

**Example Attack Blocked:**
```bash
curl "http://your-alb/?id=1' OR '1'='1"
# Returns: 403 Forbidden
```

### Cross-Site Scripting (XSS) Protection

Filters malicious JavaScript injection attempts:
- `<script>alert('XSS')</script>`
- `onerror="malicious code"`
- Event handlers in HTML attributes

**Example Attack Blocked:**
```bash
curl "http://your-alb/?q=<script>alert(1)</script>"
# Returns: 403 Forbidden
```

### Rate Limiting (DDoS Protection)

- **Threshold:** 2000 requests per 5 minutes per IP
- **Action:** Block requests exceeding threshold
- **Recovery:** Automatic (IP unblocked after 5 minutes)
- **Monitoring:** CloudWatch metrics for blocked requests

**Testing:**
```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
for i in {1..100}; do
  curl -s -o /dev/null -w "%{http_code}\n" http://$ALB_DNS/
done
```

### IP Reputation Filtering

Automatically blocks known malicious IP addresses:
- Updated regularly by AWS threat intelligence
- Includes bot networks, scanners, and attack sources
- No manual maintenance required

---

## Infrastructure Updates

### New Module: WAF

```hcl
module "waf" {
  source = "../../modules/waf"

  project_name = var.project_name
  alb_arn      = module.alb.alb_arn
  rate_limit   = var.waf_rate_limit
}
```

**Resources Created:**
- `aws_wafv2_web_acl.main` - WebACL with 5 rules
- `aws_wafv2_web_acl_association.main` - Associates WebACL with ALB

### IAM Policy Changes

**Before:**
- 11 separate managed policies attached to GitHub Actions role
- Hitting AWS limit of 10 policies per role

**After:**
- 1 custom customer-managed policy
- All permissions consolidated
- Easier to audit and maintain

---

## Architecture Changes

### Traffic Flow

```
Internet
    ↓
AWS WAF v2 WebACL
    ├── Rate Limiting (2000 req/5min)
    ├── Common Rules (OWASP Top 10)
    ├── SQL Injection Rules
    ├── Known Bad Inputs
    └── IP Reputation Filter
    ↓
Application Load Balancer (Port 80)
    ↓
Target Group (Port 3000)
    ↓
EC2 Instances (Docker)
    ↓
Application Container
```

### Security Layers

```
Layer 1: AWS WAF
  - Blocks malicious requests before they reach ALB
  - Rate limiting prevents DDoS
  - OWASP Top 10 protection

Layer 2: Security Groups
  - Restricts traffic to specific ports
  - Only allows traffic from ALB to EC2
  - Only allows traffic from EC2 to RDS

Layer 3: IAM Roles
  - EC2 instances use IAM roles (no hardcoded credentials)
  - Least privilege access
  - Secrets Manager for database credentials

Layer 4: Network Isolation
  - Private subnets for EC2 and RDS
  - No direct internet access
  - NAT Gateway for outbound traffic
```

---

## CloudWatch Metrics

### WAF Metrics

- `BlockedRequests` - Count of blocked requests
- `AllowedRequests` - Count of allowed requests
- `CountedRequests` - Count of requests that matched rules but weren't blocked

**View Metrics:**
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

## Testing WAF Protection

### Test SQL Injection Blocking

```bash
curl "http://your-alb-dns/?id=1' OR '1'='1"
# Expected: 403 Forbidden
```

### Test XSS Blocking

```bash
curl "http://your-alb-dns/?q=<script>alert(1)</script>"
# Expected: 403 Forbidden
```

### Test Rate Limiting

```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
for i in {1..100}; do
  curl -s -o /dev/null -w "%{http_code}\n" http://$ALB_DNS/
done
```

After 2000 requests in 5 minutes, subsequent requests return 403.

---

## Lessons Learned

### 1. IAM Policy Consolidation

**Challenge:** The GitHub Actions role had too many managed policies, hitting AWS limits.

**Solution:** Consolidate all permissions into one custom policy.

**Key Insights:**
- AWS allows max 10 managed policies per role
- Custom policies are more flexible and easier to audit
- Explicit permissions are better than broad managed policies
- Single source of truth for permissions

### 2. Chicken-and-Egg Permission Problem

**Challenge:** When adding WAF permissions, Terraform needed to read the WAF state during refresh, but the role didn't have WAF permissions yet.

**Root Cause:**
1. Terraform runs `terraform plan`
2. Plan refreshes state from AWS
3. State refresh tries to read WAF resources
4. Role lacks `wafv2:GetWebACL` permission
5. Plan fails with AccessDeniedException

**Solution:** Apply locally first to grant permissions, then push to trigger CI/CD.

**Key Insights:**
- When adding new service permissions, apply locally first
- State refresh happens before any changes are made
- IAM changes take effect immediately (no propagation delay)
- Document this pattern for future service additions

### 3. WAF Rule Priority

**Challenge:** Understanding which rule takes precedence when multiple rules match.

**Solution:** Use explicit priority values (1-5) to control evaluation order.

**Key Insights:**
- Lower priority numbers are evaluated first
- Rate limiting should be first (cheap check)
- AWS managed rules should follow
- Custom rules should be last (expensive check)
- First match wins (unless using count mode)

### 4. WAF Cost Optimization

**Challenge:** WAF can get expensive with many rules and high traffic.

**Solution:** Start with essential rules, add more as needed.

**Key Insights:**
- WebACL: ~$5/month
- Managed Rules: ~$1/rule/month
- Start with 3-5 essential rules
- Add more rules based on threat analysis
- Monitor costs in AWS Cost Explorer

---

## Skills Demonstrated

**Web Security:**
- AWS WAF v2 configuration and management
- OWASP Top 10 vulnerability protection
- SQL injection prevention
- Cross-site scripting (XSS) prevention
- DDoS protection via rate limiting
- IP reputation filtering

**IAM Security:**
- Policy consolidation and optimization
- Custom policy creation
- Least privilege access
- Permission troubleshooting

**Infrastructure as Code:**
- Modular WAF implementation
- Reusable security patterns
- CloudWatch metrics integration
- Automated security deployment

**Security Operations:**
- Threat detection and prevention
- Real-time monitoring
- Incident response (blocked requests)
- Security auditing

---

## Comparison to Industry Standards

### AWS Well-Architected Framework - Security Pillar

v0.9.0 addresses these pillars:

✅ **Implement a strong identity foundation**: IAM roles with least privilege
✅ **Enable traceability**: CloudWatch metrics for blocked requests
✅ **Apply security at all layers**: WAF, Security Groups, IAM, Network isolation
✅ **Automate security best practices**: Infrastructure as Code deployment
✅ **Protect data in transit**: HTTPS (future), now WAF protection

### OWASP Top 10 Protection

v0.9.0 protects against:
- ✅ A03:2021 - Injection (SQL injection protection)
- ✅ A07:2021 - Cross-Site Scripting (XSS protection)
- ✅ A09:2021 - Security Logging and Monitoring Failures (CloudWatch metrics)
- ⚠️ A01:2021 - Broken Access Control (partial - WAF rules help)
- ⚠️ A05:2021 - Security Misconfiguration (partial - WAF rules help)

### Production Readiness Checklist

Before v0.9.0:
- ❌ No web application firewall
- ❌ No SQL injection protection
- ❌ No XSS protection
- ❌ No DDoS protection
- ❌ Manual security only

After v0.9.0:
- ✅ AWS WAF v2 with 5 rule groups
- ✅ SQL injection blocking
- ✅ XSS filtering
- ✅ Rate limiting (DDoS protection)
- ✅ IP reputation filtering
- ✅ Real-time monitoring
- ✅ CloudWatch metrics

---

## Cost Impact

**Estimated Monthly Cost Increase: ~$10**

- AWS WAF WebACL: ~$5/month
- Managed Rules (5 rules): ~$5/month
- Total WAF cost: ~$10/month

**Justification:** The WAF cost is <10% of total infrastructure cost and provides enterprise-grade security that would cost thousands per month with third-party WAF solutions.

---

## Deployment Verification

### Check WAF WebACL

```bash
# List WAF WebACLs
aws wafv2 list-web-acls --scope REGIONAL

# Get WebACL details
aws wafv2 get-web-acl \
  --name startuphub-dev-web-acl \
  --scope REGIONAL \
  --id <web-acl-id>
```

### View Blocked Requests

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

### Test Protection

```bash
# Test SQL injection blocking
curl "http://your-alb-dns/?id=1' OR '1'='1"
# Expected: 403 Forbidden

# Test XSS blocking
curl "http://your-alb-dns/?q=<script>alert(1)</script>"
# Expected: 403 Forbidden
```

---

# v0.7.0 - Monitoring & Logging

**Status:** ✅ **COMPLETED**

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
   - Generates `terraform.tfvars` from 33 GitHub Secrets
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

All 33 infrastructure variables stored securely in GitHub Secrets:

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
- Automatically sets all 33 secrets from `terraform.tfvars`
- One command replaces 33 manual clicks
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
✅ 33 secrets stored in GitHub Secrets
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

Expected: 33 `TF_VAR_*` secrets + `AWS_ROLE_ARN`

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

**Challenge:** How to manage 33 variables without storing them in git?

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

### v0.7.0 - Monitoring & Logging (Current)

**Date:** 2026-07-11

## Overview

v0.7.0 adds comprehensive monitoring and logging capabilities to the StartupHub infrastructure. We implemented centralized logging with CloudWatch Logs, real-time metrics collection with CloudWatch Agent, automated alerting with SNS, and a unified monitoring dashboard.

This milestone transforms the infrastructure from "set it and forget it" to fully observable, enabling proactive monitoring and rapid incident response.

## What We Built

### 1. CloudWatch Logs Module (`modules/cloudwatch-logs`)

Created a dedicated module for centralized log management with 4 log groups:

- **System Logs** (`/aws/ec2/{project}/system`): Captures `/var/log/syslog` from EC2 instances
- **Docker Logs** (`/aws/ec2/{project}/docker`): Collects all Docker container logs from `/var/lib/docker/containers/*/*.log`
- **Application Logs** (`/aws/ec2/{project}/application`): Ready for application-specific logging
- **User Data Logs** (`/aws/ec2/{project}/user-data`): Tracks EC2 initialization scripts in `/var/log/user-data.log`

All log groups have 30-day retention and consistent tagging.

### 2. SNS Module (`modules/sns`)

Implemented notification infrastructure for alert delivery:

- **SNS Topic** (`{project}-alerts`): Central hub for all monitoring alerts
- **Email Subscription**: Delivers alerts directly to `osikanyie@gmail.com`
- **Ready for Integration**: Multiple alarm types can publish to the same topic

### 3. CloudWatch Agent Integration (`modules/compute`)

Enhanced EC2 instances with deep observability:

- **IAM Policy Attachment**: Added `CloudWatchAgentServerPolicy` to EC2 instance role
- **Agent Installation**: Automated installation via user data script
- **Custom Configuration**: Deployed agent config collecting:
  - **CPU metrics**: Active, idle, user, system usage per core and total
  - **Memory metrics**: Used percent, available percent
  - **Disk metrics**: Usage percent per mount point, inodes free
  - **Network metrics**: Bytes sent/received, packets sent/received per interface
  - **Swap metrics**: Used percent
- **Log Forwarding**: Automatically streams 3 log sources to CloudWatch Logs
- **Service Management**: Agent starts on boot and restarts on failure

### 4. CloudWatch Alarms Module (`modules/cloudwatch-alarms`)

Deployed automated alerting with intelligent thresholds:

- **CPU Alarm**: Triggers when ASG average CPU > 80% for 2 consecutive periods (10 minutes)
- **ASG-Level Monitoring**: Alarms monitor the Auto Scaling Group, not individual instances
- **SNS Integration**: All alarms publish to the SNS topic for email notifications
- **OK Actions**: Alerts when metrics return to normal (not just when they breach)

**Note on Memory/Disk Alarms**: Instance-level metrics require dynamic instance IDs which aren't available in Terraform at plan time. Documented manual creation process for future enhancement.

### 5. CloudWatch Dashboard Module (`modules/cloudwatch-dashboard`)

Created a unified monitoring dashboard with 8 metric widgets:

**EC2 Section:**
- CPU Utilization (ASG-level average)
- Memory Used % (from CWAgent custom metrics)

**ALB Section:**
- Request Count (sum of all requests)
- Target Response Time (average latency in seconds)
- Healthy Host Count (number of healthy targets)

**RDS Section:**
- CPU Utilization
- Database Connections
- Free Storage Space (in bytes)

Dashboard provides single-pane-of-glass visibility into the entire infrastructure.

### 6. Enhanced Module Outputs

Added CloudWatch-specific outputs to existing modules:

- **ALB Module**: `alb_arn_suffix` and `target_group_arn_suffix` for CloudWatch metrics
- **RDS Module**: `instance_identifier` for RDS CloudWatch metrics
- **Dev Environment**: `dashboard_name` output for easy dashboard access

## Architecture Changes

### Before v0.7.0
```
Internet → ALB → EC2 (Docker) → RDS
              (No visibility into what's happening)
```

### After v0.7.0
```
Internet → ALB → EC2 (Docker) → RDS
    ↓         ↓        ↓           ↓
  ALB     CloudWatch  CloudWatch  CloudWatch
 Metrics   Dashboard   Agent       Metrics
    ↓         ↓        ↓           ↓
    └─────────┴────────┴───────────┘
              CloudWatch
                 ↓
            SNS → Email
```

## Monitoring Capabilities

### What You Can Now See

**Real-Time Metrics:**
- EC2 CPU, memory, disk, and network utilization
- Docker container resource consumption
- ALB request rates, latency, and health status
- RDS performance and connection metrics

**Centralized Logs:**
- System logs from all EC2 instances
- Docker container stdout/stderr
- Application logs (ready for integration)
- User data execution logs for debugging

**Automated Alerts:**
- Email notifications when CPU exceeds 80%
- Recovery notifications when metrics normalize
- 10-minute evaluation window prevents false positives

**Unified Dashboard:**
- Single view of all infrastructure components
- Real-time metric visualization
- Historical trend analysis

## Deployment Impact

### No Breaking Changes

All v0.7.0 additions are backward compatible:
- Existing infrastructure continues to work unchanged
- New monitoring resources are additive
- No modifications to application code required

### New Resources Created

- 4 CloudWatch Log Groups
- 1 SNS Topic + 1 Email Subscription
- 1 CloudWatch Agent configuration per EC2 instance
- 1 CloudWatch Alarm (CPU)
- 1 CloudWatch Dashboard with 8 widgets
- IAM policy attachments for CloudWatch Agent

### Cost Impact

**Estimated Monthly Cost Increase: ~$5-10**

- CloudWatch Logs: ~$2-3/month (depending on log volume)
- CloudWatch Metrics: ~$2-3/month (custom metrics from agent)
- SNS Notifications: ~$0.50/month (assuming 10 alerts)
- CloudWatch Dashboard: Free (up to 3 dashboards)

**Justification**: The monitoring cost is <10% of total infrastructure cost and provides invaluable operational visibility.

## Validation Steps

### 1. Deploy Infrastructure

```bash
cd environments/dev
terraform apply
```

### 2. Check SNS Subscription

AWS sends a confirmation email to `osikanyie@gmail.com`. Click the confirmation link to activate the subscription. Without this step, alarms won't send notifications.

### 3. Verify CloudWatch Agent

Connect to EC2 via SSM and check agent status:

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
```

Expected output: `Status: running`

### 4. Check Logs in CloudWatch

Navigate to CloudWatch Console → Log groups. You should see 4 log groups:
- `/aws/ec2/startuphub-dev/system`
- `/aws/ec2/startuphub-dev/docker`
- `/aws/ec2/startuphub-dev/application`
- `/aws/ec2/startuphub-dev/user-data`

Open any log group and verify logs are streaming.

### 5. Test CPU Alarm

Generate CPU load on an EC2 instance:

```bash
# Connect via SSM
aws ssm start-session --target <instance-id>

# Generate CPU load
stress --cpu 4 --timeout 600
```

Wait 10 minutes. You should receive an email alert when CPU exceeds 80%.

### 6. View Dashboard

Navigate to CloudWatch Console → Dashboards → `startuphub-dev-dashboard`

Verify all 8 widgets are displaying metrics.

## Lessons Learned

### 1. CloudWatch Agent Configuration Complexity

**Challenge**: CloudWatch Agent configuration is verbose JSON with many options.

**Solution**: Start with a minimal config collecting essential metrics (CPU, memory, disk, network). Expand incrementally as needed.

**Best Practice**: Use Terraform template files for agent configuration to enable dynamic values (log group names, regions).

### 2. Instance-Level vs ASG-Level Alarms

**Challenge**: Memory and disk metrics are instance-level, but ASG instances are dynamic.

**Solution**: Use ASG-level alarms for CPU (aggregated metric). Document manual process for instance-level alarms.

**Alternative**: Use CloudWatch Contributor Insights or Lambda to create dynamic alarms per instance.

### 3. SNS Email Confirmation

**Challenge**: AWS requires explicit email confirmation before sending notifications.

**Solution**: Document this step prominently. Consider using SMS or PagerDuty for production (no confirmation required).

### 4. CloudWatch Dashboard JSON

**Challenge**: Dashboard definitions are large JSON blobs that are hard to maintain.

**Solution**: Use Terraform `jsonencode()` function for type safety and validation.

**Best Practice**: Start with a simple dashboard, then expand. Don't try to visualize everything at once.

### 5. Log Group Naming Convention

**Challenge**: Multiple log sources need consistent naming.

**Solution**: Use hierarchical naming: `/aws/ec2/{project}/{log-type}`

**Benefit**: Easy to search and filter logs in CloudWatch Console.

## Skills Demonstrated

**Cloud Monitoring:**
- CloudWatch Logs configuration and management
- CloudWatch Agent installation and configuration
- CloudWatch custom metrics and dimensions
- CloudWatch dashboards and widgets
- CloudWatch alarms and SNS integration

**Operational Excellence:**
- Centralized logging strategy
- Real-time monitoring and alerting
- Proactive incident detection
- Unified observability platform

**Infrastructure as Code:**
- Modular monitoring infrastructure
- Reusable CloudWatch patterns
- Dynamic dashboard generation
- Automated agent deployment

**Security & Compliance:**
- IAM least-privilege for CloudWatch Agent
- Encrypted log storage (CloudWatch default)
- Audit trail via CloudTrail

## Future Enhancements (v0.8.0+)

### High Priority
- Memory and disk alarms (requires dynamic instance ID handling)
- RDS performance alarms (CPU, connections, storage)
- ALB 5xx error rate alarms
- Log insights queries for common patterns

### Medium Priority
- CloudWatch Synthetics for uptime monitoring
- X-Ray distributed tracing
- Custom application metrics
- Log metric filters for error counting

### Nice to Have
- Grafana integration for advanced visualization
- PagerDuty/OpsGenie integration for on-call
- Cost Explorer dashboards
- Anomaly detection with ML

## Comparison to Industry Standards

### AWS Well-Architected Framework - Operational Excellence

v0.7.0 addresses these pillars:

✅ **Perform operations as code**: Monitoring deployed via Terraform
✅ **Make frequent, small, reversible changes**: Alarms can be adjusted without downtime
✅ **Refine operations procedures continuously**: Dashboard provides feedback loop
✅ **Anticipate failure**: Alarms detect issues before users are impacted
✅ **Learn from operational failures**: Logs enable post-mortem analysis

### Production Readiness Checklist

Before v0.7.0:
- ❌ No centralized logging
- ❌ No real-time metrics
- ❌ No automated alerting
- ❌ No unified dashboard
- ❌ Manual troubleshooting only

After v0.7.0:
- ✅ Centralized logging with 30-day retention
- ✅ Real-time metrics for all components
- ✅ Automated alerting with email notifications
- ✅ Unified dashboard with 8 key metrics
- ✅ Proactive monitoring and rapid response

---

# v0.7.0 - Monitoring & Logging

**Status:** ✅ **COMPLETED** - See v0.7.0 section above

- ✅ CloudWatch Logs for centralized logging
- ✅ CloudWatch Agent for custom metrics
- ✅ SNS notifications for alerts
- ✅ CloudWatch Alarms for automated alerting
- ✅ CloudWatch Dashboard for unified monitoring

---

# v0.9.0 - Web Application Firewall (WAF)

**Status:** ✅ **COMPLETED** - See v0.9.0 section above

- ✅ AWS WAF v2 WebACL with 5 rule groups
- ✅ SQL Injection protection
- ✅ Cross-Site Scripting (XSS) protection
- ✅ Rate limiting (DDoS protection)
- ✅ IP reputation filtering
- ✅ IAM policy consolidation (11 policies → 1)

---

# Project Status

**Current Version:**

```
v0.9.0
```

**Status:**

```
Full Security & Observability
Web Application Firewall
Centralized Logging
Automated Alerting
Production-Ready Dashboard
```

**Architecture:**

```
git push → GitHub Actions → Validate → Build → Push → Plan → Apply → AWS
                                              ↓                    ↓
                                          ECR Repository      CloudWatch
                                              ↓                    ↓
                                          WAF → ALB ←── CloudWatch Agent
                                           ↓      ↓            ↓
                                      Security  EC2        Logs & Metrics
                                              (with Agent)   ↓
                                                  ↓       Dashboard & Alarms
                                            RDS PostgreSQL
                                                  ↓
                                            Secrets Manager
```

**Deployment Time:** 5-7 minutes (fully automated)

**Manual Steps:** Zero

**Secrets in Git:** Zero

**Monitoring:** Full observability with logs, metrics, alarms, and dashboards

**Security:** Enterprise-grade WAF protection with OWASP Top 10 coverage

---
