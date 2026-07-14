# Troubleshooting Guide

## Table of Contents

1. [Deployment Issues](#deployment-issues)
2. [EC2 Instance Problems](#ec2-instance-problems)
3. [Docker Container Issues](#docker-container-issues)
4. [Database Connection Problems](#database-connection-problems)
5. [ALB Health Check Failures](#alb-health-check-failures)
6. [CI/CD Pipeline Issues](#cicd-pipeline-issues)
7. [Network and Security Group Issues](#network-and-security-group-issues)
8. [Performance Problems](#performance-problems)
9. [Monitoring and Alerting Issues](#monitoring-and-alerting-issues)
10. [Terraform State Issues](#terraform-state-issues)
11. [Cost Optimization](#cost-optimization)
12. [Emergency Procedures](#emergency-procedures)

---

## Deployment Issues

### Problem: Terraform Apply Fails

**Symptoms:**
```
Error: error creating VPC: InvalidCIDRBlock
```

**Solutions:**

#### 1. Invalid CIDR Block

**Check:**
```bash
terraform plan
```

**Fix:**
```bash
# Edit terraform.tfvars
nano terraform.tfvars

# Ensure CIDR blocks are valid:
vpc_cidr = "10.0.0.0/16"
public_subnet_1_cidr = "10.0.1.0/24"
# etc.

# Verify with CIDR calculator:
# https://www.ipaddressguide.com/cidr
```

#### 2. Insufficient Permissions

**Check:**
```bash
aws sts get-caller-identity
aws iam get-user
```

**Fix:**
```bash
# Attach required policies
aws iam attach-user-policy \
  --user-name YOUR_USER \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

#### 3. Region Mismatch

**Check:**
```bash
aws configure list
```

**Fix:**
```bash
aws configure
# Set default region to match your AMI and configuration
```

#### 4. AMI Not Available in Region

**Check:**
```bash
aws ec2 describe-images --image-ids ami-0c55b159cbfafe1f0
```

**Fix:**
```bash
# Find AMI in your region
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --region us-east-1

# Update terraform.tfvars with correct AMI ID
```

#### 5. Resource Already Exists

**Check:**
```bash
terraform state list
```

**Fix:**
```bash
# Import existing resource
terraform import module.networking.aws_vpc.this vpc-12345678

# Or destroy and recreate
terraform destroy
terraform apply
```

---

## EC2 Instance Problems

### Problem: Instance Stuck in "Pending" State

**Symptoms:**
```bash
aws ec2 describe-instances --instance-ids i-1234567890abcdef0
# Status: pending (never becomes running)
```

**Solutions:**

#### 1. Insufficient Capacity

**Check:**
```bash
aws ec2 describe-instance-status --instance-ids i-1234567890abcdef0
```

**Fix:**
```bash
# Try different AZ or instance type
# Update terraform.tfvars
instance_type = "t3.small"  # Instead of t3.micro
```

#### 2. User Data Script Errors

**Check:**
```bash
# Get instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=startuphub-dev-*" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)

# Get user data
aws ec2 describe-instance-attribute \
  --instance-id ${INSTANCE_ID} \
  --attribute userData

# Check system log
aws ec2 get-console-output --instance-id ${INSTANCE_ID}
```

**Fix:**
```bash
# Review user_data.tpl for errors
cat modules/compute/user_data.tpl

# Common issues:
# - Missing newline at end of file
# - Invalid bash syntax
# - Missing variables
```

#### 3. Security Group Blocking SSH/SSM

**Check:**
```bash
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw ec2_security_group_id)
```

**Fix:**
```bash
# Ensure SSM is allowed (port 443 outbound)
# Already configured in security module
```

### Problem: Instance Launches but Fails Health Checks

**Symptoms:**
```bash
aws elbv2 describe-target-health
# State: unhealthy, Reason: Target.FailedHealthChecks
```

**Solutions:**

#### 1. Application Not Listening on Correct Port

**Check:**
```bash
# Connect to instance
aws ssm start-session --target ${INSTANCE_ID}

# Check if container is running
sudo docker ps

# Check container logs
sudo docker logs <container-id>

# Check if port is listening
sudo netstat -tlnp | grep 3000
```

**Fix:**
```bash
# Update Dockerfile to expose correct port
# Ensure application binds to 0.0.0.0:3000
```

#### 2. User Data Script Failed

**Check:**
```bash
# View user data logs
sudo cat /var/log/user-data.log

# Or via CloudWatch
aws logs tail /aws/ec2/startuphub-dev/user-data --since 1h
```

**Common errors:**
```
# Docker pull failed
Error response from daemon: manifest for ... not found

# Solution: Ensure image exists in ECR
aws ecr list-images --repository-name startuphub-dev-app
```

#### 3. Health Check Path Incorrect

**Check:**
```bash
# Test health endpoint manually
curl http://localhost:3000/health

# Check ALB target group configuration
aws elbv2 describe-target-groups --names startuphub-dev-tg
```

**Fix:**
```bash
# Update health check path in modules/alb/main.tf
health_check {
  path = "/health"  # Or "/" if that's your health endpoint
}
```

### Problem: Instance Terminates Unexpectedly

**Symptoms:**
```bash
aws autoscaling describe-scaling-activities
# Cause: Instance terminated due to failed health checks
```

**Solutions:**

#### 1. Increase Health Check Grace Period

**Fix:**
```bash
# Update modules/autoscaling/main.tf
resource "aws_autoscaling_group" "this" {
  health_check_grace_period = 600  # Increase from 300 to 600 seconds
}
```

#### 2. Check ASG Termination Policies

**Check:**
```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names startuphub-dev-asg
```

**Fix:**
```bash
# Adjust termination policies if needed
```

---

## Docker Container Issues

### Problem: Container Won't Start

**Symptoms:**
```bash
sudo docker ps -a
# Status: Exited (1)
```

**Solutions:**

#### 1. Missing Environment Variables

**Check:**
```bash
sudo docker logs <container-id>
# Error: DB_HOST is required
```

**Fix:**
```bash
# Update user_data.tpl to pass all required env vars
docker run -d \
  -e DB_HOST=${rds_endpoint} \
  -e DB_PORT=${rds_port} \
  -e DB_NAME=${db_name} \
  -e DB_USER=${db_username} \
  -e DB_PASSWORD=${db_password} \
  ${ecr_repository_url}:${image_tag}
```

#### 2. Application Crash on Startup

**Check:**
```bash
sudo docker logs <container-id>
# Node.js error stack trace
```

**Fix:**
```bash
# Review application code
cat app/server.js

# Test locally
cd app
docker build -t test .
docker run -it test
```

#### 3. Database Connection Timeout

**Check:**
```bash
sudo docker logs <container-id>
# Error: connect ETIMEDOUT
```

**Fix:**
```bash
# Check security group allows port 5432
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw rds_security_group_id)

# Verify RDS is in same VPC
aws rds describe-db-instances \
  --db-instance-identifier startuphub-dev-postgres
```

### Problem: Container Runs but Application Not Responding

**Symptoms:**
```bash
sudo docker ps
# Status: Up 5 minutes

curl http://localhost:3000/
# Connection refused
```

**Solutions:**

#### 1. Application Not Binding to 0.0.0.0

**Check:**
```bash
sudo docker logs <container-id>
# Server listening on 127.0.0.1:3000
```

**Fix:**
```javascript
// Update app/server.js
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});
```

#### 2. Port Mapping Incorrect

**Check:**
```bash
sudo docker ps
# PORTS: 3000/tcp (not 0.0.0.0:3000->3000/tcp)
```

**Fix:**
```bash
# Update user_data.tpl
docker run -d \
  -p 3000:3000 \  # Ensure -p flag is present
  ${ecr_repository_url}:${image_tag}
```

#### 3. Firewall Blocking Port

**Check:**
```bash
sudo iptables -L -n

# Or via security group
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw ec2_security_group_id)
```

**Fix:**
```bash
# Security group already allows port 3000 from ALB
# Verify in modules/security/main.tf
```

### Problem: Container Image Pull Fails

**Symptoms:**
```bash
sudo docker pull ${ECR_URL}:latest
# Error: unauthorized: authentication required
```

**Solutions:**

#### 1. ECR Authentication Failed

**Check:**
```bash
# Verify IAM role has ECR permissions
aws iam list-attached-role-policies --role-name startuphub-dev-ec2-role
```

**Fix:**
```bash
# Ensure IAM role has AmazonEC2ContainerRegistryReadOnly policy
aws iam attach-role-policy \
  --role-name startuphub-dev-ec2-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
```

#### 2. Image Doesn't Exist

**Check:**
```bash
aws ecr list-images --repository-name startuphub-dev-app
```

**Fix:**
```bash
# Push image to ECR
./scripts/build-and-push.sh
```

#### 3. ECR Repository Policy Blocking

**Check:**
```bash
aws ecr get-repository-policy \
  --repository-name startuphub-dev-app
```

**Fix:**
```bash
# Update repository policy to allow EC2 role
```

---

## Database Connection Problems

### Problem: Cannot Connect to RDS

**Symptoms:**
```bash
psql -h ${RDS_ENDPOINT} -U startupadmin -d startuphub
# Error: could not connect to server: Connection timed out
```

**Solutions:**

#### 1. RDS Not in Available State

**Check:**
```bash
aws rds describe-db-instances \
  --db-instance-identifier startuphub-dev-postgres \
  --query "DBInstances[0].DBInstanceStatus"
# Status: creating (not available)
```

**Fix:**
```bash
# Wait for RDS to be available (10-15 minutes)
aws rds wait db-instance-available \
  --db-instance-identifier startuphub-dev-postgres
```

#### 2. Security Group Blocking

**Check:**
```bash
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw rds_security_group_id) \
  --query "SecurityGroups[0].IpPermissions"
```

**Fix:**
```bash
# Verify security group allows port 5432 from EC2 security group
# Update modules/security/main.tf if needed
```

#### 3. Wrong Endpoint

**Check:**
```bash
terraform output rds_endpoint
# Should be: startuphub-dev-postgres.cxxxxxxx.us-east-1.rds.amazonaws.com
```

**Fix:**
```bash
# Get correct endpoint
aws rds describe-db-instances \
  --db-instance-identifier startuphub-dev-postgres \
  --query "DBInstances[0].Endpoint.Address" \
  --output text
```

#### 4. Wrong Credentials

**Check:**
```bash
# Verify username
terraform output db_username

# Test connection
PGPASSWORD=${DB_PASSWORD} psql -h ${RDS_ENDPOINT} -U startupadmin -d startuphub
```

**Fix:**
```bash
# Reset password if needed
aws rds modify-db-instance \
  --db-instance-identifier startuphub-dev-postgres \
  --master-user-password "NewPassword123!" \
  --apply-immediately
```

### Problem: Database Connection Pool Exhausted

**Symptoms:**
```bash
# Application logs
Error: too many connections for role "startupadmin"
```

**Solutions:**

#### 1. Too Many Connections

**Check:**
```bash
# Connect to RDS
psql -h ${RDS_ENDPOINT} -U startupadmin -d startuphub

# Check connections
SELECT count(*) FROM pg_stat_activity;

# Check max connections
SHOW max_connections;
```

**Fix:**
```bash
# Increase max connections (requires restart)
aws rds modify-db-instance \
  --db-instance-identifier startuphub-dev-postgres \
  --db-parameter-group-name startuphub-dev-params \
  --apply-immediately

# Or use connection pooling (PgBouncer)
```

#### 2. Connection Leaks

**Check:**
```bash
# Check idle connections
SELECT * FROM pg_stat_activity WHERE state = 'idle';
```

**Fix:**
```javascript
// Update app/server.js - use connection pooling
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,  // Limit pool size
  idleTimeoutMillis: 30000,  // Close idle connections
  connectionTimeoutMillis: 2000,  // Timeout for new connections
});
```

---

## ALB Health Check Failures

### Problem: All Targets Unhealthy

**Symptoms:**
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)
# All targets: unhealthy
```

**Solutions:**

#### 1. Health Check Path Returns Non-200

**Check:**
```bash
# Get instance private IP
INSTANCE_IP=$(aws ec2 describe-instances \
  --instance-ids ${INSTANCE_ID} \
  --query "Reservations[0].Instances[0].PrivateIpAddress" \
  --output text)

# Test from within VPC (use SSM)
aws ssm start-session --target ${INSTANCE_ID}

# Once connected:
curl http://localhost:3000/health
# Should return 200 OK
```

**Fix:**
```bash
# Update health check endpoint in application
# Ensure it returns 200 status code
```

#### 2. Health Check Timeout Too Short

**Check:**
```bash
aws elbv2 describe-target-groups --names startuphub-dev-tg
# Timeout: 5 seconds
```

**Fix:**
```bash
# Increase timeout
aws elbv2 modify-target-group \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --health-check-timeout 10 \
  --health-check-interval-seconds 30
```

#### 3. Security Group Blocking ALB

**Check:**
```bash
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw ec2_security_group_id) \
  --query "SecurityGroups[0].IpPermissions"
```

**Fix:**
```bash
# Ensure EC2 security group allows port 3000 from ALB security group
# Already configured in modules/security/main.tf
```

### Problem: Targets Flapping (Healthy/Unhealthy)

**Symptoms:**
```bash
# Targets frequently change state
aws elbv2 describe-target-health
# State changes every few minutes
```

**Solutions:**

#### 1. Application Unstable

**Check:**
```bash
sudo docker logs <container-id> --tail 100
# Look for errors or crashes
```

**Fix:**
```bash
# Fix application bugs
# Add proper error handling
# Implement graceful shutdown
```

#### 2. Resource Exhaustion

**Check:**
```bash
# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=${INSTANCE_ID} \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**Fix:**
```bash
# Increase instance size
instance_type = "t3.small"  # Or larger

# Or scale horizontally
desired_capacity = 4
```

---

## CI/CD Pipeline Issues

### Problem: GitHub Actions Workflow Fails

**Symptoms:**
- Workflow shows red X
- Job fails with error

**Solutions:**

#### 1. Missing GitHub Secrets

**Check:**
```bash
gh secret list
```

**Fix:**
```bash
./scripts/set-github-secrets.sh
```

#### 2. Terraform Format Check Fails

**Check:**
```bash
# View workflow logs
gh run view <run-id> --log
```

**Fix:**
```bash
# Format code
terraform fmt -recursive

# Commit and push
git add .
git commit -m "fix: format terraform code"
git push origin main
```

#### 3. Terraform Validate Fails

**Check:**
```bash
cd environments/dev
terraform validate
```

**Fix:**
```bash
# Fix validation errors
# Common issues:
# - Missing required variables
# - Invalid resource configuration
# - Circular dependencies
```

#### 4. AWS Credentials Invalid

**Check:**
```bash
# Check OIDC role
aws iam get-role --role-name GitHubActionsRole
```

**Fix:**
```bash
# Ensure OIDC provider exists
aws iam list-open-id-connect-providers

# Recreate if needed
terraform apply -target=module.iam.aws_iam_openid_connect_provider.github
```

#### 5. Docker Build Fails

**Check:**
```bash
# View build logs
gh run view <run-id> --log | grep -A 20 "Build Docker"
```

**Fix:**
```bash
# Test locally
cd app
docker build -t test .

# Fix Dockerfile issues
```

### Problem: Workflow Runs but Doesn't Deploy

**Symptoms:**
- Workflow shows green checkmark
- Infrastructure unchanged

**Solutions:**

#### 1. No Changes Detected

**Check:**
```bash
git log --oneline
```

**Fix:**
```bash
# Make actual changes
echo "test" >> README.md
git add .
git commit -m "test: trigger deployment"
git push origin main
```

#### 2. Path Filter Excludes Changes

**Check:**
```bash
cat .github/workflows/ci-cd.yml
# paths: section
```

**Fix:**
```yaml
# Update paths filter
on:
  push:
    branches: [main]
    paths:
      - 'modules/**'
      - 'environments/**'
      - 'app/**'
      - '.github/workflows/**'
```

---

## Network and Security Group Issues

### Problem: Cannot Access ALB from Internet

**Symptoms:**
```bash
curl http://${ALB_DNS}
# Connection timeout
```

**Solutions:**

#### 1. ALB Not in Public Subnets

**Check:**
```bash
aws elbv2 describe-load-balancers --names startuphub-dev-alb \
  --query "LoadBalancers[0].AvailabilityZones"
```

**Fix:**
```bash
# ALB should be in public subnets
# Check modules/alb/main.tf
```

#### 2. Security Group Blocking

**Check:**
```bash
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw alb_security_group_id) \
  --query "SecurityGroups[0].IpPermissions"
```

**Fix:**
```bash
# Ensure ALB security group allows port 80 from 0.0.0.0/0
# Check modules/security/main.tf
```

#### 3. Route Table Missing Internet Gateway

**Check:**
```bash
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"
```

**Fix:**
```bash
# Ensure public subnet route table has route to IGW
```

### Problem: EC2 Cannot Access Internet

**Symptoms:**
```bash
# From EC2 instance (via SSM)
curl https://aws.amazon.com
# Connection timeout
```

**Solutions:**

#### 1. NAT Gateway Not Running

**Check:**
```bash
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
  --query "NatGateways[0].State"
# Should be: available
```

**Fix:**
```bash
# Wait for NAT Gateway to be available
aws ec2 wait nat-gateway-available \
  --nat-gateway-ids $(aws ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
    --query "NatGateways[0].NatGatewayId" \
    --output text)
```

#### 2. Private Subnet Route Table Missing NAT Route

**Check:**
```bash
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=$(terraform output -raw private_subnet_1_id)"
```

**Fix:**
```bash
# Ensure private subnet route table has route to NAT Gateway
```

---

## Performance Problems

### Problem: Slow Application Response

**Symptoms:**
```bash
time curl http://${ALB_DNS}/
# real: 0m5.000s (should be < 1s)
```

**Solutions:**

#### 1. Database Query Slow

**Check:**
```bash
# Connect to RDS
psql -h ${RDS_ENDPOINT} -U startupadmin -d startuphub

# Check slow queries
SELECT * FROM pg_stat_activity WHERE state = 'active';

# Check query performance
EXPLAIN ANALYZE SELECT * FROM tasks WHERE id = 1;
```

**Fix:**
```sql
-- Add indexes
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_created_at ON tasks(created_at DESC);
```

#### 2. Instance Under-Provisioned

**Check:**
```bash
# Check CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=startuphub-dev-asg \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**Fix:**
```bash
# Increase instance size
instance_type = "t3.small"
```

#### 3. Not Enough Instances

**Check:**
```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names startuphub-dev-asg \
  --query "AutoScalingGroups[0].DesiredCapacity"
```

**Fix:**
```bash
# Scale horizontally
desired_capacity = 4
min_size = 4
```

### Problem: High Memory Usage

**Symptoms:**
```bash
# CloudWatch alarm triggers
# Memory > 80%
```

**Solutions:**

#### 1. Memory Leak in Application

**Check:**
```bash
# From EC2 instance
free -h
ps aux | grep node
```

**Fix:**
```bash
# Restart containers
sudo docker restart $(sudo docker ps -q)

# Or restart instances
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name startuphub-dev-asg
```

#### 2. Insufficient Memory

**Check:**
```bash
free -h
# total: 1.0GB (t3.micro has only 1GB RAM)
```

**Fix:**
```bash
# Use larger instance type
instance_type = "t3.small"  # 2GB RAM
```

---

## Monitoring and Alerting Issues

### Problem: Not Receiving Email Alerts

**Symptoms:**
- CloudWatch alarm triggers
- No email received

**Solutions:**

#### 1. SNS Subscription Not Confirmed

**Check:**
```bash
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform output -raw sns_topic_arn) \
  --query "Subscriptions[0].SubscriptionArn"
# Should not be: "PendingConfirmation"
```

**Fix:**
```bash
# Check email for confirmation link
# Or manually confirm
aws sns confirm-subscription \
  --topic-arn $(terraform output -raw sns_topic_arn) \
  --token "TOKEN_FROM_EMAIL"
```

#### 2. Email in Spam Folder

**Check:**
```bash
# Check spam folder
```

**Fix:**
```bash
# Add AWS to safe senders
# Or use different email address
alert_email = "your-email@example.com"
```

#### 3. SNS Topic Policy Blocking

**Check:**
```bash
aws sns get-topic-attributes \
  --topic-arn $(terraform output -raw sns_topic_arn)
```

**Fix:**
```bash
# Update topic policy to allow CloudWatch
```

### Problem: Missing Metrics in CloudWatch

**Symptoms:**
```bash
aws cloudwatch list-metrics \
  --namespace CWAgent \
  --metric-name MemoryUsedPercent
# No data
```

**Solutions:**

#### 1. CloudWatch Agent Not Running

**Check:**
```bash
# From EC2 instance
sudo systemctl status amazon-cloudwatch-agent
```

**Fix:**
```bash
sudo systemctl restart amazon-cloudwatch-agent
sudo systemctl enable amazon-cloudwatch-agent
```

#### 2. Agent Configuration Incorrect

**Check:**
```bash
sudo cat /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
```

**Fix:**
```bash
# Update user_data.tpl with correct configuration
# Ensure memory metrics are enabled
```

---

## Terraform State Issues

### Problem: State Lock Error

**Symptoms:**
```bash
terraform apply
# Error: Error acquiring the state lock
```

**Solutions:**

#### 1. Stale Lock

**Check:**
```bash
terraform force-unlock <LOCK_ID>
```

**Fix:**
```bash
# Force unlock
terraform force-unlock LOCK_ID_FROM_ERROR
```

#### 2. Concurrent Apply

**Check:**
```bash
# Ensure only one person running terraform apply
```

**Fix:**
```bash
# Wait for other apply to complete
# Or coordinate with team
```

### Problem: State Drift

**Symptoms:**
```bash
terraform plan
# Shows changes even though nothing was modified
```

**Solutions:**

#### 1. Manual Changes in AWS Console

**Check:**
```bash
terraform plan
# Review drift
```

**Fix:**
```bash
# Option 1: Revert manual changes in AWS Console
# Option 2: Update Terraform code to match
# Option 3: Import manual changes
terraform import <resource> <id>
```

#### 2. State File Corrupted

**Check:**
```bash
terraform state list
# Error or incomplete list
```

**Fix:**
```bash
# Restore from backup
aws s3 cp s3://startuphub-terraform-state/terraform.tfstate.backup ./

# Or use state versioning
aws s3api list-object-versions \
  --bucket startuphub-terraform-state \
  --key terraform.tfstate
```

---

## Cost Optimization

### Problem: Unexpected High Costs

**Symptoms:**
```bash
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
# Cost much higher than expected
```

**Solutions:**

#### 1. Unused Resources

**Check:**
```bash
# List all resources
terraform state list

# Check for unattached EBS volumes
aws ec2 describe-volumes \
  --filters "Name=status,Values=available"

# Check for unattached Elastic IPs
aws ec2 describe-addresses \
  --filters "Name=domain,Values=vpc"
```

**Fix:**
```bash
# Delete unused resources
aws ec2 delete-volume --volume-id vol-12345678
aws ec2 release-address --allocation-id eipalloc-12345678
```

#### 2. Oversized Instances

**Check:**
```bash
# Check utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=${INSTANCE_ID} \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average
```

**Fix:**
```bash
# Downsize if average < 30%
instance_type = "t3.micro"
```

#### 3. NAT Gateway Costs

**Check:**
```bash
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter '{"Dimensions":{"Key":"Service","Values":["Amazon Virtual Private Cloud"]}}'
```

**Fix:**
```bash
# Use VPC endpoints for AWS services
# Reduces NAT Gateway data transfer costs
```

---

## Emergency Procedures

### Procedure: Complete Infrastructure Failure

**Scenario:** All resources lost, need immediate recovery

**Steps:**

#### 1. Assess Situation
```bash
# Check AWS Console for resource status
# Review CloudTrail for recent changes
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=TerminateInstances \
  --max-results 10
```

#### 2. Restore Terraform State
```bash
# Get latest state from S3
aws s3 cp s3://startuphub-terraform-state/terraform.tfstate ./

# Or use backup
aws s3 cp s3://startuphub-terraform-state/terraform.tfstate.backup ./
```

#### 3. Redeploy Infrastructure
```bash
cd environments/dev
terraform init
terraform plan  # Review
terraform apply
```

#### 4. Rebuild Docker Image
```bash
./scripts/build-and-push.sh
```

#### 5. Verify Recovery
```bash
terraform output
curl http://${ALB_DNS}/health
```

**Time:** 30-60 minutes

### Procedure: Security Breach

**Scenario:** Suspected unauthorized access

**Steps:**

#### 1. Isolate Affected Resources
```bash
# Stop EC2 instances
aws ec2 stop-instances --instance-ids ${INSTANCE_ID}

# Revoke security group rules
aws ec2 revoke-security-group-ingress \
  --group-id ${SG_ID} \
  --protocol all \
  --port all \
  --cidr 0.0.0.0/0
```

#### 2. Rotate Credentials
```bash
# Rotate RDS password
aws rds modify-db-instance \
  --db-instance-identifier startuphub-dev-postgres \
  --master-user-password "NewSecurePassword!" \
  --apply-immediately

# Rotate IAM access keys
aws iam create-access-key --user-name YOUR_USER
# Delete old key
aws iam delete-access-key --user-name YOUR_USER --access-key-id OLD_KEY
```

#### 3. Investigate
```bash
# Review CloudTrail logs
aws cloudtrail lookup-events \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --max-results 50

# Check VPC Flow Logs
aws ec2 describe-flow-logs
```

#### 4. Rebuild from Clean State
```bash
terraform destroy
terraform apply
./scripts/build-and-push.sh
```

**Time:** 1-2 hours

---

## Getting Help

### Internal Resources

- **Architecture:** See `ARCHITECTURE.md`
- **Deployment:** See `DEPLOYMENT.md`
- **Costs:** See `COST.md`
- **Milestones:** See `milestone-history.md`

### External Resources

- **AWS Documentation:** https://docs.aws.amazon.com/
- **Terraform Documentation:** https://www.terraform.io/docs
- **Docker Documentation:** https://docs.docker.com/
- **AWS Support:** https://console.aws.amazon.com/support/

### Common AWS CLI Commands

```bash
# Check resource status
aws ec2 describe-instances --instance-ids i-1234567890abcdef0
aws rds describe-db-instances --db-instance-identifier startuphub-dev-postgres
aws elbv2 describe-target-health --target-group-arn ${TG_ARN}

# View logs
aws logs tail /aws/ec2/startuphub-dev/system --since 1h
aws ec2 get-console-output --instance-id ${INSTANCE_ID}

# Check metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=${INSTANCE_ID} \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Connect to instance
aws ssm start-session --target ${INSTANCE_ID}
```

---

## Troubleshooting Checklist

Use this checklist when issues arise:

### Infrastructure
- [ ] Terraform state is valid (`terraform state list`)
- [ ] All resources are in expected state (`terraform plan`)
- [ ] No drift detected

### EC2 Instances
- [ ] Instances are running (`aws ec2 describe-instances`)
- [ ] User data completed successfully (check logs)
- [ ] Docker is running (`sudo docker ps`)
- [ ] Container is healthy

### Application
- [ ] Application is listening on port 3000
- [ ] Health endpoint returns 200
- [ ] Can connect to database
- [ ] No errors in application logs

### Networking
- [ ] Security groups allow required traffic
- [ ] Route tables are correct
- [ ] NAT Gateway is available
- [ ] ALB targets are healthy

### Monitoring
- [ ] CloudWatch Agent is running
- [ ] Metrics are being published
- [ ] Alarms are in OK state
- [ ] SNS subscription confirmed

### CI/CD
- [ ] GitHub secrets are set
- [ ] Workflow runs successfully
- [ ] Docker image is pushed to ECR
- [ ] Terraform apply completes

---

**Remember:** When in doubt, check the logs first. 90% of issues can be diagnosed by reviewing application, system, or user data logs.
