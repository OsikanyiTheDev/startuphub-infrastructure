# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-07-11

### Fixed
- **CI/CD Deploy Job** - Simplified deploy job to always refresh ASG on push to main
  - Removed conditional logic that only refreshed when `app/` files changed
  - Now every push triggers automatic ASG instance refresh
  - Ensures new Docker images are always deployed
  - Zero-downtime deployment maintained with 100% healthy instances

## [1.0.0] - 2026-07-11

### 🎉 Major Release: Production-Grade Infrastructure

This is the first stable production release of StartupHub Infrastructure.

### Added
- **Comprehensive Documentation Suite**
  - ARCHITECTURE.md - Detailed system architecture with diagrams
  - DEPLOYMENT.md - Complete deployment and operations guide
  - TROUBLESHOOTING.md - 12 troubleshooting categories with solutions
  - COST.md - Detailed cost analysis (~$107/month) and optimization strategies
  - RELEASE_NOTES_v1.0.0.md - Comprehensive release announcement
  - CHANGELOG.md - Version history (this file)

- **13 Terraform Modules**
  - VPC and networking
  - Security groups
  - EC2 and Auto Scaling
  - Application Load Balancer
  - RDS PostgreSQL
  - ECR container registry
  - IAM roles and policies
  - CloudWatch logs, metrics, alarms, dashboard
  - SNS notifications
  - WAF protection
  - IAM for GitHub Actions

- **Complete CI/CD Pipeline**
  - GitHub Actions workflow with 4 stages
  - Automated deployment on git push
  - 35 encrypted secrets managed securely
  - OIDC authentication (no AWS access keys)
  - Path-based triggers for efficiency

- **Security Features**
  - AWS WAF v2 with 5 managed rule groups
  - Zero hardcoded credentials
  - OIDC federation for GitHub Actions
  - AWS Secrets Manager for database credentials
  - Network isolation with private subnets
  - Encryption at rest for all storage
  - IAM least privilege principles

- **Monitoring & Observability**
  - CloudWatch Logs with 30-day retention
  - CloudWatch Agent for custom metrics
  - 8-widget dashboard for real-time monitoring
  - Automated alarms with SNS notifications
  - WAF metrics for security monitoring

### Security
- Consolidated 11 IAM managed policies into 1 custom policy
- Implemented OIDC authentication for GitHub Actions
- Added AWS WAF v2 with OWASP Top 10 protection
- Enabled encryption at rest for EBS and RDS
- Implemented network isolation with private subnets
- Configured security groups with least privilege access

### Documentation
- Added comprehensive architecture documentation
- Created step-by-step deployment guide
- Documented troubleshooting procedures
- Provided detailed cost analysis
- Added performance benchmarks
- Included disaster recovery procedures

### Performance
- Response time: < 200ms average
- Throughput: ~1000 requests/second
- Multi-AZ deployment for high availability
- Auto Scaling Group with health checks

### Cost
- Estimated monthly cost: ~$107
- Breakdown provided in COST.md
- Optimization strategies documented
- Reserved Instance recommendations: 30-40% savings

---

## [0.9.0] - 2026-07-11

### Added
- AWS WAF v2 WebACL with 5 managed rule groups
  - Rate limiting (2000 requests per 5 minutes per IP)
  - SQL Injection protection
  - Cross-Site Scripting (XSS) protection
  - Known Bad Inputs protection
  - IP Reputation filtering
- WAF CloudWatch metrics
- WAF rule priority configuration

### Changed
- IAM policy consolidated from 11 managed policies to 1 custom policy
- GitHub Actions role updated with WAF permissions

### Security
- Added WAF protection to Application Load Balancer
- Blocked common SQL injection patterns
- Blocked XSS attack vectors
- Rate limiting to prevent DDoS attacks

---

## [0.8.0] - Skipped

### Note
Version 0.8.0 was planned for HTTPS support with ACM certificates and Route53 DNS integration, but was skipped due to domain ownership requirements. This feature is planned for v1.1.0.

---

## [0.7.0] - 2026-07-11

### Added
- CloudWatch Logs module with 4 log groups
  - System logs (/var/log/syslog)
  - Docker container logs
  - Application logs
  - User data logs
- CloudWatch Agent installation and configuration
- Custom metrics collection
  - CPU utilization
  - Memory usage
  - Disk usage
  - Network I/O
  - Swap usage
- CloudWatch Alarms module
  - CPU > 80% for 10 minutes
  - Memory > 80% for 10 minutes
  - Disk > 90% for 10 minutes
- CloudWatch Dashboard with 8 widgets
- SNS module for email notifications
- SNS topic and email subscription

### Changed
- EC2 IAM role updated with CloudWatch permissions
- User data script enhanced with CloudWatch Agent installation

### Documentation
- Added monitoring and observability sections
- Documented CloudWatch Agent configuration

---

## [0.6.0] - 2026-07-11

### Added
- GitHub Actions CI/CD pipeline
  - Validate Terraform job
  - Build and Push Docker Image job
  - Terraform Plan job
  - Terraform Apply job
- IAM module for GitHub Actions
  - OIDC provider configuration
  - GitHub Actions IAM role
  - Policy attachments
- GitHub Secrets automation script
- Path-based workflow triggers

### Changed
- Consolidated IAM policies from 11 managed policies to 1 custom policy
- Updated workflow to include all 35 secrets

### Security
- Implemented OIDC authentication (no AWS access keys)
- Encrypted all secrets in GitHub
- Least privilege IAM policies

### Documentation
- Added CI/CD setup guide
- Documented GitHub Secrets configuration
- Created secrets automation script

---

## [0.5.0] - 2026-07-11

### Added
- Docker application (Node.js + Express)
  - Task Manager API
  - Health check endpoint
  - Database integration
- Dockerfile with multi-stage build
- Build and push script for ECR
- ECR repository module
- User data script for EC2 Docker installation

### Changed
- Launch template updated to use user data script
- EC2 instances automatically install Docker and pull image

### Fixed
- Port configuration mismatch (ALB port 80 → Target port 3000)
- Security group rules updated for port 3000

### Documentation
- Added container deployment section
- Documented Docker build process

---

## [0.4.0] - 2026-07-10

### Added
- Amazon RDS PostgreSQL instance
- DB subnet group
- RDS security group
- Secrets Manager integration
  - Automatic password generation
  - EC2 IAM policy for secret access
- Database initialization script

### Changed
- Security group rules to allow PostgreSQL traffic (port 5432)
- Application updated to use database connection

### Security
- Database deployed in private subnets
- Encrypted storage
- IAM-based access to credentials

---

## [0.3.0] - 2026-07-10

### Added
- EC2 IAM role with SSM permissions
- IAM instance profile
- SSM policy attachment
- Enhanced security group rules

### Changed
- Removed SSH access (port 22)
- All access via AWS Systems Manager Session Manager
- IMDSv2 required for EC2 instances

### Security
- No SSH keys required
- No exposed SSH ports
- Centralized access management
- Improved audit logging

---

## [0.2.0] - 2026-07-10

### Added
- Application Load Balancer module
  - Public subnets placement
  - HTTP listener (port 80)
  - Target group configuration
- Auto Scaling Group module
  - Launch template integration
  - Health checks
  - Rolling updates
- EC2 Launch Template module
  - AMI configuration
  - Instance type
  - Security groups

### Changed
- Route tables updated for public/private subnets
- NAT Gateway configuration for private subnet internet access

---

## [0.1.0] - 2026-07-10

### Added
- Initial project structure
- Terraform configuration
- VPC module
  - CIDR block: 10.0.0.0/16
- Subnet modules
  - 2 public subnets
  - 2 private application subnets
  - 2 private database subnets
- Internet Gateway
- NAT Gateway
- Elastic IP for NAT Gateway
- Route tables
  - Public route table with IGW
  - Private route table with NAT
- Security groups (placeholder)

### Security
- Network isolation implemented
- Public subnets for ALB only
- Private subnets for EC2 and RDS

---

## Versioning Scheme

This project uses [Semantic Versioning](https://semver.org/):

- **MAJOR** version (X.0.0): Breaking changes, major architectural shifts
- **MINOR** version (0.X.0): New features, modules, capabilities (backward compatible)
- **PATCH** version (0.0.X): Bug fixes, documentation updates (backward compatible)

---

## Upgrade Guide

### From 0.9.0 to 1.0.0
No breaking changes. This is a documentation-only release.

```bash
git pull origin main
```

### From 0.7.0 to 1.0.0
No breaking changes. Review new documentation files.

```bash
git pull origin main
```

### From 0.6.0 to 1.0.0
WAF module added. Apply to create WAF resources.

```bash
git pull origin main
cd environments/dev
terraform apply
```

### From 0.5.0 to 1.0.0
Monitoring and WAF modules added. Apply to create new resources.

```bash
git pull origin main
cd environments/dev
terraform apply
```

---

## Known Issues

### None in v1.0.0
All known issues have been resolved in this release.

### Future Considerations
- HTTPS requires domain ownership (planned for v1.1.0)
- Memory/disk alarms require custom CloudWatch Agent configuration
- NAT Gateway costs can be optimized with VPC endpoints

---

## Deprecations

### None
No features are deprecated in v1.0.0.

---

## Removed

### None
No features have been removed in v1.0.0.

---

## Statistics

### Code Metrics (v1.0.0)
- **Terraform Files:** 40+
- **Lines of Code:** 2,500+
- **Modules:** 13
- **AWS Resources:** 50+
- **Documentation Pages:** 5 major documents
- **Total Documentation:** 1,500+ lines

### Infrastructure Resources
- **VPC:** 1
- **Subnets:** 6
- **Security Groups:** 4
- **EC2 Instances:** 2 (auto-scaling 2-4)
- **Load Balancers:** 1
- **RDS Instances:** 1
- **ECR Repositories:** 1
- **CloudWatch Log Groups:** 4
- **CloudWatch Alarms:** 3
- **WAF Rule Groups:** 5
- **IAM Roles:** 2
- **IAM Policies:** 5

---

## Contributors

- **Osikanyi Essandoh** - Initial development and architecture

---

*Last Updated: July 11, 2026*
*Current Version: 1.0.0*
