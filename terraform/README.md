# Terraform Infrastructure for Multi-Cloud Demo

This directory contains Terraform configurations to deploy Kubernetes clusters on both Amazon EKS and Azure AKS with integrated monitoring and logging.

## Overview

Both deployments create production-ready Kubernetes clusters with:
- Autoscaling node pools
- Integrated monitoring and logging
- Container registries (ACR/ECR)
- Network security best practices
- Storage encryption
- RBAC and pod security

## Prerequisites

### Installation Instructions

#### macOS Installation

**Install Homebrew** (if not already installed):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Install required tools:**
```bash
# PowerShell 7
brew install --cask powershell

# Terraform
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# kubectl
brew install kubectl

# Helm
brew install helm

# Azure CLI (for AKS)
brew install azure-cli

# AWS CLI (for EKS)
brew install awscli

# Optional: TFLint for enhanced validation
brew install tflint

# Optional: Pre-commit for git hooks
brew install pre-commit
```

**Verify installations:**
```bash
pwsh --version          # Should be 7.0+
terraform --version     # Should be 1.3.0+
kubectl version --client
helm version
az --version
aws --version
```

#### Windows Installation

**Install PowerShell 7** (if not already installed):
```powershell
# Using winget (Windows 10 1709+)
winget install Microsoft.PowerShell

# Or download from: https://github.com/PowerShell/PowerShell/releases
```

**Install package managers:**
```powershell
# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Or install Scoop (alternative)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
```

**Install tools using Chocolatey:**
```powershell
# Core tools
choco install terraform
choco install kubernetes-cli
choco install kubernetes-helm
choco install azure-cli
choco install awscli

# Optional tools
choco install tflint
choco install git
```

**Install tools using Scoop** (alternative):
```powershell
# Add buckets
scoop bucket add main
scoop bucket add extras

# Install tools
scoop install terraform
scoop install kubectl
scoop install helm
scoop install azure-cli
scoop install aws

# Optional
scoop install tflint
scoop install git
```

**Manual Installation** (if package managers unavailable):
- **Terraform**: Download from [terraform.io/downloads](https://www.terraform.io/downloads)
- **kubectl**: Download from [kubernetes.io/docs/tasks/tools/install-kubectl-windows/](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/)
- **Helm**: Download from [helm.sh/docs/intro/install/](https://helm.sh/docs/intro/install/)
- **Azure CLI**: Download from [docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows)
- **AWS CLI**: Download from [aws.amazon.com/cli/](https://aws.amazon.com/cli/)

**Verify installations:**
```powershell
pwsh $PSVersionTable.PSVersion  # Should be 7.0+
terraform --version             # Should be 1.3.0+
kubectl version --client
helm version
az --version
aws --version
```

#### Linux Installation (Ubuntu/Debian)

```bash
# Update package list
sudo apt update

# PowerShell 7
wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt update
sudo apt install -y powershell

# Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt update && sudo apt install terraform

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt update && sudo apt install helm

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Authentication Setup

#### Azure Authentication
```bash
# Login to Azure
az login

# Set subscription (if you have multiple)
az account set --subscription "Your Subscription Name"

# Verify login
az account show

# Register required Azure resource providers
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.Authorization

# Verify provider registration (may take a few minutes)
az provider show --namespace Microsoft.ContainerService --query registrationState
az provider show --namespace Microsoft.OperationsManagement --query registrationState
```

#### AWS Authentication
```bash
# Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region, Output format

# Or use environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Verify credentials
aws sts get-caller-identity
```

### Required Permissions

#### Azure AKS Permissions
Your Azure account needs these roles:
- `Contributor` on the subscription or resource group
- `User Access Administrator` (for role assignments)
- `Azure Kubernetes Service Cluster Admin Role`

#### AWS EKS Permissions
Your AWS user/role needs these policies:
- `AmazonEKSClusterPolicy`
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`
- `EC2FullAccess` (for VPC/subnet management)
- `IAMFullAccess` (for service roles)

### Optional Enhancements

#### TFLint Configuration
```bash
# Create .tflint.hcl in your terraform directory
cat > .tflint.hcl << EOF
plugin "aws" {
    enabled = true
    version = "0.21.2"
    source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

plugin "azurerm" {
    enabled = true
    version = "0.22.0"
    source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
EOF

# Initialize TFLint
tflint --init
```

#### Pre-commit Hooks Setup
```bash
# Install pre-commit (if not already installed)
pip install pre-commit

# Install hooks in your repository
cd /path/to/multi-cloud-demo
pre-commit install

# Run hooks on all files (optional)
pre-commit run --all-files
```

### Common Installation Issues

**PowerShell Execution Policy (Windows)**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**PATH Issues**:
- Ensure all tools are in your system PATH
- Restart terminal/PowerShell after installation
- Use `where terraform` (Windows) or `which terraform` (macOS/Linux) to verify

**Azure CLI Login Issues**:
```bash
# Clear cache and re-login
az account clear
az login --use-device-code
```

**AWS CLI Configuration**:
```bash
# Check configuration
aws configure list

# Test with a simple command
aws sts get-caller-identity
```

## Validation

Before deploying infrastructure, validate your configurations:

### Quick Validation
```powershell
# Validate all configurations
.\validate-terraform.ps1

# Validate specific environment
.\validate-terraform.ps1 -Environment aks
.\validate-terraform.ps1 -Environment eks

# Auto-fix formatting issues
.\validate-terraform.ps1 -Fix

# Detailed validation output
.\validate-terraform.ps1 -Detailed
```

### Environment-Specific Validation
```powershell
# Validate AKS with Azure connectivity check
cd aks
.\validate-aks.ps1 -CheckAzure -Detailed

# Validate EKS with AWS connectivity check
cd eks
.\validate-eks.ps1 -CheckAWS -Detailed
```

### What Gets Validated
- **Terraform formatting** (terraform fmt)
- **Configuration syntax** (terraform validate)
- **Provider configurations**
- **Required variables and outputs**
- **Security best practices**
- **Cloud-specific naming conventions**
- **Monitoring and logging setup**
- **Resource dependencies**

## Quick Start

### Deploy AKS Infrastructure

```powershell
# Deploy AKS cluster with default settings
.\deploy-aks-infra.ps1

# Deploy with custom settings
.\deploy-aks-infra.ps1 -ResourceGroupName "my-aks-rg" -Location "westus2" -ClusterName "my-aks"

# Plan before applying
.\deploy-aks-infra.ps1 -Plan

# Auto-approve deployment
.\deploy-aks-infra.ps1 -AutoApprove

# Destroy infrastructure
.\deploy-aks-infra.ps1 -Destroy
```

### Deploy EKS Infrastructure

```powershell
# Deploy EKS cluster with default settings
.\deploy-eks-infra.ps1

# Deploy with custom settings  
.\deploy-eks-infra.ps1 -Region "us-west-2" -ClusterName "my-eks"

# Plan before applying
.\deploy-eks-infra.ps1 -Plan

# Auto-approve deployment
.\deploy-eks-infra.ps1 -AutoApprove

# Destroy infrastructure
.\deploy-eks-infra.ps1 -Destroy
```

## What Gets Created

### AKS Resources
- **Resource Group**: Container for all resources
- **AKS Cluster**: Managed Kubernetes with system node pool
- **Virtual Network**: Dedicated VNet with subnet
- **Log Analytics Workspace**: For monitoring and logs
- **Application Insights**: Application performance monitoring
- **Storage Account**: For diagnostic logs
- **Container Registry** (optional): Azure Container Registry
- **Azure Policy**: Enabled for compliance
- **Microsoft Defender**: Security monitoring

### EKS Resources
- **VPC**: Multi-AZ VPC with public/private subnets
- **EKS Cluster**: Managed Kubernetes control plane
- **Node Group**: Managed EC2 instances with autoscaling
- **IAM Roles**: For service accounts (IRSA)
- **CloudWatch Logs**: Cluster and application logs
- **S3 Bucket**: Log archive storage
- **ECR Repository** (optional): Docker image registry
- **Load Balancer Controller**: AWS Load Balancer Controller
- **EBS CSI Driver**: For persistent volumes
- **Container Insights**: CloudWatch Container Insights

## Monitoring and Logging

### AKS Monitoring
- **Azure Monitor**: Integrated container insights
- **Log Analytics**: Query logs with KQL
- **Application Insights**: APM for applications
- **Diagnostic Settings**: Control plane logs

Access monitoring:
```bash
# Azure Portal
https://portal.azure.com -> Your AKS Cluster -> Insights

# Query logs
az monitor log-analytics query \
  --workspace $WORKSPACE_ID \
  --analytics-query "ContainerLog | take 10"
```

### EKS Monitoring
- **CloudWatch Container Insights**: Metrics and logs
- **CloudWatch Logs**: Centralized logging
- **S3 Archive**: Long-term log retention
- **X-Ray** (optional): Distributed tracing

Access monitoring:
```bash
# CloudWatch Console
https://console.aws.amazon.com/cloudwatch/ -> Container Insights

# Query logs
aws logs tail /aws/eks/multi-cloud-demo-eks/cluster --follow
```

## Configuration

### Customize AKS Deployment

Edit `terraform/aks/terraform.tfvars`:
```hcl
resource_group_name  = "my-custom-rg"
location            = "westeurope"
cluster_name        = "production-aks"
kubernetes_version  = "1.28.3"
default_node_count  = 3
min_node_count      = 3
max_node_count      = 10
default_node_vm_size = "Standard_D8s_v3"
log_retention_days  = 90
create_acr          = true
acr_name           = "mycompanyacr"
```

### Customize EKS Deployment

Edit `terraform/eks/terraform.tfvars`:
```hcl
aws_region          = "eu-west-1"
cluster_name        = "production-eks"
kubernetes_version  = "1.28"
node_instance_type  = "m5.2xlarge"
min_node_count      = 3
max_node_count      = 10
desired_node_count  = 5
log_retention_days  = 90
enable_ecr          = true
ecr_repository_name = "my-app"
```

## Cost Optimization

### AKS Cost Savings
- Use spot instances for non-critical workloads
- Enable cluster autoscaler
- Use Azure Advisor recommendations
- Schedule dev/test clusters to shut down

### EKS Cost Savings
- Use Spot instances for worker nodes
- Implement Cluster Autoscaler
- Use AWS Compute Savings Plans
- Enable Cost Allocation Tags

## Security Best Practices

Both deployments implement:
- Network isolation with private subnets
- Encryption at rest for all storage
- RBAC enabled by default
- Pod security standards
- Audit logging enabled
- Container image scanning
- Managed identities/IRSA

## Troubleshooting

### Validation Issues

**Terraform format errors**
```powershell
# Auto-fix formatting
.\validate-terraform.ps1 -Fix

# Or manually
terraform fmt -recursive
```

**Configuration validation fails**
```powershell
# Check syntax errors
terraform validate

# Detailed error information
.\validate-terraform.ps1 -Detailed
```

**Missing variables**
```powershell
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars
# Edit with your values
```

**Cloud provider authentication**
```powershell
# Azure authentication issues
az login
az account show

# AWS authentication issues  
aws configure
aws sts get-caller-identity
```

### Common AKS Issues

**Cluster creation fails**
```bash
# Check deployment status
az aks show -g $RG -n $CLUSTER --query provisioningState

# View activity log
az monitor activity-log list -g $RG --offset 1h
```

**Node pool issues**
```bash
# Scale node pool
az aks nodepool scale -g $RG --cluster-name $CLUSTER -n default --node-count 3

# Check node pool status
az aks nodepool show -g $RG --cluster-name $CLUSTER -n default
```

### Common EKS Issues

**Cluster creation fails**
```bash
# Check CloudFormation stack
aws cloudformation describe-stacks --stack-name eksctl-$CLUSTER-cluster

# View cluster status
aws eks describe-cluster --name $CLUSTER --query cluster.status
```

**Node group issues**
```bash
# Check node group status
aws eks describe-nodegroup --cluster-name $CLUSTER --nodegroup-name default-ng

# View autoscaling activity
aws autoscaling describe-scaling-activities --auto-scaling-group-name $ASG_NAME
```

## State Management

Terraform state is stored locally by default. For production:

### Remote State for AKS
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstateaccount"
    container_name      = "tfstate"
    key                 = "aks.terraform.tfstate"
  }
}
```

### Remote State for EKS
```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "terraform-state-lock"
  }
}
```

## Clean Up

Remove all resources to avoid charges:

```powershell
# Destroy AKS infrastructure
.\deploy-aks-infra.ps1 -Destroy -AutoApprove

# Destroy EKS infrastructure  
.\deploy-eks-infra.ps1 -Destroy -AutoApprove
```

## Integration with Application

After infrastructure deployment:

1. **Deploy the demo application**
   ```powershell
   cd ..
   .\deploy-aks.ps1  # or .\deploy-eks.ps1
   ```

2. **Configure CI/CD**
   - Use the container registry URLs from Terraform outputs
   - Configure kubectl contexts for deployment
   - Set up monitoring dashboards

3. **Test disaster recovery**
   - Practice cluster backup/restore
   - Test node failure scenarios
   - Validate autoscaling under load

---

## 🤖 Built with Claude Code

This infrastructure automation demonstrates cloud-native Kubernetes deployments with enterprise-grade monitoring and security.