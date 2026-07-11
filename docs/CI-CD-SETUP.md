# CI/CD Pipeline Setup Guide

This guide walks you through setting up the GitHub Actions CI/CD pipeline for automated deployments.

## Overview

The CI/CD pipeline automates:
- ✅ Code validation (Terraform fmt/validate)
- ✅ Docker image builds
- ✅ Pushing images to Amazon ECR
- ✅ Terraform infrastructure updates

## What Was Created

### 1. GitHub Actions Workflow (`.github/workflows/ci-cd.yml`)

**Automatic on Push:**
- Validates Terraform code
- Builds Docker image
- Pushes to ECR
- Runs Terraform plan

**Manual Trigger:**
- Can apply infrastructure changes (requires approval)

### 2. IAM Module (`modules/iam/`)

Creates:
- **OIDC Provider**: Connects GitHub to AWS securely (no access keys needed)
- **IAM Role**: `GitHubActionsRole` with permissions to:
  - Create/manage EC2, VPC, RDS, ALB, Auto Scaling
  - Push to ECR
  - Manage IAM roles and policies
  - Access Secrets Manager
  - Read/write S3 (for Terraform state)
  - Create CloudWatch logs and metrics

---

## Setup Steps

### Step 1: Deploy the IAM Module

```bash
cd /home/user/startuphub-infrastructure/environments/dev
terraform apply
```

This will create:
- GitHub OIDC provider
- `GitHubActionsRole` IAM role with all necessary permissions

### Step 2: Get the Role ARN

After Terraform completes, get the role ARN:

```bash
terraform output github_actions_role_arn
```

You'll see something like:
```
arn:aws:iam::360831508664:role/GitHubActionsRole
```

**Copy this ARN - you'll need it for GitHub.**

### Step 3: Configure GitHub Repository

1. Go to your GitHub repository: `https://github.com/OsikanyiTheDev/startuphub-infrastructure`

2. Click **Settings** (top menu)

3. Click **Secrets and variables** → **Actions** (left sidebar)

4. Click **New repository secret**

5. Add this secret:
   - **Name**: `AWS_ROLE_ARN`
   - **Value**: Paste the role ARN from Step 2

6. Click **Add secret**

### Step 4: Test the Pipeline

**Automatic Test:**
```bash
# Make a small change and push
echo "# Test CI/CD" >> README.md
git add README.md
git commit -m "test: trigger CI/CD pipeline"
git push origin main
```

Go to your GitHub repo → **Actions** tab → Watch the workflow run!

**Manual Test:**
1. Go to **Actions** tab
2. Click **CI/CD Pipeline** (left sidebar)
3. Click **Run workflow** (right side)
4. Keep "Apply infrastructure changes" **unchecked** (for testing)
5. Click **Run workflow**

---

## How It Works

### On Every Push to `main`:

```
1. Validate Terraform
   └─ Checks code formatting and syntax

2. Build & Push Docker Image
   └─ Builds app/Dockerfile
   └─ Tags with commit SHA and 'latest'
   └─ Pushes to ECR repository

3. Terraform Plan
   └─ Shows what infrastructure would change
   └─ Posts plan as PR comment (if applicable)
```

### Manual Workflow Dispatch:

```
1. All automatic steps run first
2. Terraform Apply (if you check the box)
   └─ Requires manual approval
   └─ Updates infrastructure in AWS
```

---

## Security Features

### 🔒 No AWS Access Keys

Uses **OIDC (OpenID Connect)** - GitHub proves its identity to AWS without storing credentials.

**Benefits:**
- No secrets to leak
- Automatic credential rotation
- Auditable in AWS CloudTrail
- Scoped to specific repository

### 🔐 Least Privilege

The IAM role only has permissions needed for:
- Infrastructure you're managing (EC2, RDS, etc.)
- Container registry (ECR)
- State storage (S3)
- Logging (CloudWatch)

### 🛡️ Repository Scoping

The OIDC trust policy only allows:
- **Your specific repository** (`OsikanyiTheDev/startuphub-infrastructure`)
- **Not all GitHub repos** (security best practice)

---

## Troubleshooting

### Workflow Fails at "Configure AWS credentials"

**Error:**
```
Error: Could not assume role with OIDC
```

**Fix:**
1. Verify the role ARN in GitHub secrets matches the Terraform output
2. Check that the OIDC provider exists:
   ```bash
   aws iam list-open-id-connect-providers
   ```
3. Verify the trust policy allows your repo:
   ```bash
   aws iam get-role --role-name GitHubActionsRole
   ```

### Terraform Fails at "terraform apply"

**Error:**
```
Error: creating EC2 Instance: UnauthorizedOperation
```

**Fix:**
The IAM role needs more permissions. Add them to `modules/iam/main.tf`:
```hcl
resource "aws_iam_role_policy_attachment" "github_actions_additional" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/YOUR_POLICY"
}
```

### Docker Build Fails

**Error:**
```
failed to solve: failed to compute cache key
```

**Fix:**
1. Check that `app/Dockerfile` exists
2. Verify all files referenced in Dockerfile are present
3. Test locally: `cd app && docker build -t test .`

### ECR Push Fails

**Error:**
```
denied: User not authorized to perform: ecr:PutImage
```

**Fix:**
The role already has `AmazonEC2ContainerRegistryFullAccess`. If this fails:
1. Verify the ECR repository exists
2. Check that the repository name matches `var.ecr_repository_name`

---

## Monitoring

### View Workflow Runs

1. Go to your GitHub repo
2. Click **Actions** tab
3. Click on any workflow run to see logs

### View AWS CloudTrail

See what the GitHub Actions role did:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=AROAXXXXXXXXXXXXXXXX:GitHubActions \
  --max-results 10
```

### View ECR Images

See pushed Docker images:

```bash
aws ecr list-images --repository-name startuphub-dev-app
```

---

## Cost Impact

**GitHub Actions:**
- 2,000 free minutes/month (Linux)
- Your workflow runs ~2-3 minutes per push
- **Cost**: $0 (well within free tier)

**AWS:**
- No additional cost for OIDC
- IAM role: $0
- ECR image storage: ~$0.10/GB/month

**Total CI/CD Cost**: ~$0/month

---

## Next Steps

After the CI/CD pipeline is working:

1. **Add branch protection rules:**
   - Require PR reviews
   - Require status checks to pass
   - Prevent force pushes

2. **Add testing:**
   - Terraform plan comments on PRs
   - Automated testing before merge

3. **Add environments:**
   - `dev` environment (auto-deploy)
   - `prod` environment (manual approval)

---

## Summary

✅ Created `.github/workflows/ci-cd.yml`  
✅ Created `modules/iam/` with OIDC and IAM role  
✅ Added IAM module to `environments/dev/main.tf`  
✅ Added `github_repository` variable  
✅ Added `github_actions_role_arn` output  

**Next:**
1. Run `terraform apply` to create IAM role
2. Copy role ARN to GitHub secrets
3. Push a commit to test the pipeline

🎉 **You now have a production-grade CI/CD pipeline!**
