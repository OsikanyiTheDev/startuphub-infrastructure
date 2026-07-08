v0.1.0
Core AWS Infrastructure

- VPC
- Public subnets
- Private subnets
- Internet Gateway
- NAT Gateway
- Security Groups
- Launch Template
- ALB
- Target Group
- Auto Scaling Group


v0.2.0
Private Application Layer Hardening

Implemented:

- EC2 deployed only in private subnets
- ALB-to-EC2 security model
- IMDSv2 enforcement
- Encrypted GP3 storage
- EC2 Systems Manager integration
- Removed direct SSH access
