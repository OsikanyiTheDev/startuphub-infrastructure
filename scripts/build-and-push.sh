#!/bin/bash
set -e

############################################
# StartupHub - Build & Push Docker Image
############################################
# This script builds a Docker image and pushes it to ECR
# 
# Prerequisites:
# - AWS CLI v2 installed and configured
# - Docker installed and running
# - Terraform initialized in the environment directory
# - ECR repository already created via 'terraform apply'
#
# Usage:
#   ./scripts/build-and-push.sh <environment> <dockerfile_dir> <image_tag>
#
# Example:
#   ./scripts/build-and-push.sh dev ./app latest
############################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

############################################
# Validate Arguments
############################################

if [ $# -lt 2 ]; then
    log_error "Usage: $0 <environment> <dockerfile_dir> [image_tag]"
    log_error "Example: $0 dev ./app latest"
    exit 1
fi

ENVIRONMENT=$1
DOCKERFILE_DIR=$2
IMAGE_TAG=${3:-latest}

log_info "Environment: $ENVIRONMENT"
log_info "Dockerfile directory: $DOCKERFILE_DIR"
log_info "Image tag: $IMAGE_TAG"

############################################
# Validate Prerequisites
############################################

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install it first."
    exit 1
fi

# Check Terraform
if ! command -v terraform &> /dev/null; then
    log_error "Terraform is not installed. Please install it first."
    exit 1
fi

# Verify AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials are not configured or expired."
    exit 1
fi

log_info "All prerequisites verified ✓"

############################################
# Get ECR Repository URL from Terraform
############################################

ENV_DIR="environments/$ENVIRONMENT"

if [ ! -d "$ENV_DIR" ]; then
    log_error "Environment directory '$ENV_DIR' does not exist."
    exit 1
fi

log_info "Getting ECR repository URL from Terraform output..."

cd "$ENV_DIR"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    log_info "Initializing Terraform..."
    terraform init -backend=false
fi

# Get the repository URL
REPO_URL=$(terraform output -raw repository_url 2>/dev/null)

if [ -z "$REPO_URL" ]; then
    log_error "Could not get repository_url from Terraform output."
    log_error "Make sure you've run 'terraform apply' first to create the ECR repository."
    exit 1
fi

log_info "ECR Repository URL: $REPO_URL"

# Go back to project root
cd - > /dev/null

############################################
# Extract AWS Account ID and Region
############################################

AWS_ACCOUNT_ID=$(echo "$REPO_URL" | cut -d'.' -f1)
AWS_REGION=$(echo "$REPO_URL" | cut -d'.' -f4)

log_info "AWS Account ID: $AWS_ACCOUNT_ID"
log_info "AWS Region: $AWS_REGION"

############################################
# Authenticate with ECR
############################################

log_info "Authenticating with Amazon ECR..."

aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "$REPO_URL"

if [ $? -ne 0 ]; then
    log_error "Failed to authenticate with ECR."
    exit 1
fi

log_info "ECR authentication successful ✓"

############################################
# Build Docker Image
############################################

log_info "Building Docker image..."

docker build -t "$REPO_URL:$IMAGE_TAG" "$DOCKERFILE_DIR"

if [ $? -ne 0 ]; then
    log_error "Docker build failed."
    exit 1
fi

log_info "Docker image built successfully ✓"

############################################
# Push to ECR
############################################

log_info "Pushing image to ECR..."

docker push "$REPO_URL:$IMAGE_TAG"

if [ $? -ne 0 ]; then
    log_error "Docker push failed."
    exit 1
fi

log_info "Image pushed successfully ✓"

############################################
# Success Summary
############################################

echo ""
log_info "=========================================="
log_info "Docker image deployed successfully!"
log_info "=========================================="
log_info "Image: $REPO_URL:$IMAGE_TAG"
log_info "=========================================="
