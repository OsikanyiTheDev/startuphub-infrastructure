#!/bin/bash
set -e

# Log all output for debugging
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== Starting EC2 initialization ==="
echo "ECR Repository: ${ecr_repository_url}"
echo "Image Tag: ${image_tag}"
echo "RDS Endpoint: ${rds_endpoint}"
echo "Timestamp: $(date)"

# Update system and install dependencies
echo "Installing dependencies..."
apt-get update -y
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    unzip \
    jq

# Install Docker
echo "Installing Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
systemctl start docker
systemctl enable docker
echo "Docker installed successfully"

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install --update
aws --version
cd -

# Install CloudWatch Agent
echo "Installing CloudWatch Agent..."
cd /tmp
curl -O https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb
cd -

# Configure CloudWatch Agent
echo "Configuring CloudWatch Agent..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWAGENT_CONFIG'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "cpu": {
        "resources": ["*"],
        "measurement": ["usage_active", "usage_idle", "usage_user", "usage_system"],
        "totalcpu": true
      },
      "disk": {
        "resources": ["/"],
        "measurement": ["used_percent", "inodes_free"]
      },
      "diskio": {
        "resources": ["*"],
        "measurement": ["reads", "writes", "read_bytes", "write_bytes"]
      },
      "mem": {
        "measurement": ["mem_used_percent", "mem_available_percent"]
      },
      "net": {
        "resources": ["*"],
        "measurement": ["bytes_sent", "bytes_recv", "packets_sent", "packets_recv"]
      },
      "swap": {
        "measurement": ["used_percent"]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "/aws/ec2/${project_name}/system",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/ec2/${project_name}/user-data",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/lib/docker/containers/*/*.log",
            "log_group_name": "/aws/ec2/${project_name}/docker",
            "log_stream_name": "{instance_id}/{hostname}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
CWAGENT_CONFIG

# Start CloudWatch Agent
echo "Starting CloudWatch Agent..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
echo "CloudWatch Agent configured and started"

# Authenticate with ECR using IAM role
echo "Authenticating with ECR..."
aws ecr get-login-password --region ${aws_region} | \
    docker login --username AWS --password-stdin ${ecr_repository_url}
echo "ECR authentication successful"

# Pull image from ECR
echo "Pulling image from ECR..."
docker pull ${ecr_repository_url}:${image_tag}
echo "Image pulled successfully"

# Fetch database secret from Secrets Manager
echo "Fetching database credentials from Secrets Manager..."
SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id ${rds_secret_arn} \
    --query SecretString \
    --output text)

DB_PASSWORD=$(echo $SECRET_JSON | jq -r '.password')
echo "Database credentials retrieved"

# Run the application container
echo "Starting application container..."
docker run -d \
    --name startuphub-app \
    --restart unless-stopped \
    -p 3000:3000 \
    -e DB_HOST=${rds_endpoint} \
    -e DB_PORT=${rds_port} \
    -e DB_NAME=${rds_db_name} \
    -e DB_USER=${rds_db_user} \
    -e DB_PASSWORD=$DB_PASSWORD \
    ${ecr_repository_url}:${image_tag}

echo "Container started successfully"
echo "=== EC2 initialization complete ==="
echo "Application should be available on port 3000"
