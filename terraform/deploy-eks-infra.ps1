# deploy-eks-infra.ps1 - Deploy EKS infrastructure using Terraform
# Prerequisites:
# - AWS CLI installed and configured (aws configure)
# - Terraform installed
# - PowerShell 7.0+

param(
    [switch]$Plan,
    [switch]$Destroy,
    [switch]$AutoApprove,
    [string]$Region = "us-east-1",
    [string]$ClusterName = "multi-cloud-demo-eks"
)

# Color output functions
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Write-Success { param([string]$Message) Write-ColorOutput $Message "Green" }
function Write-Info { param([string]$Message) Write-ColorOutput $Message "Cyan" }
function Write-Warning { param([string]$Message) Write-ColorOutput $Message "Yellow" }
function Write-Error { param([string]$Message) Write-ColorOutput $Message "Red" }

# Header
Write-Success "=============================================="
Write-Success "EKS Infrastructure Deployment with Terraform"
Write-Success "=============================================="

# Check prerequisites
Write-Info "Checking prerequisites..."

# Check AWS CLI
try {
    $awsVersion = aws --version 2>&1
    Write-Success "✓ AWS CLI: $awsVersion"
} catch {
    Write-Error "✗ AWS CLI not found. Please install: https://aws.amazon.com/cli/"
    exit 1
}

# Check AWS credentials
try {
    $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
    Write-Success "✓ Logged in to AWS account: $($identity.Account)"
    Write-Info "  User/Role: $($identity.Arn)"
} catch {
    Write-Error "✗ AWS credentials not configured. Please run: aws configure"
    exit 1
}

# Check Terraform
try {
    $tfVersion = terraform version -json | ConvertFrom-Json
    Write-Success "✓ Terraform version: $($tfVersion.terraform_version)"
} catch {
    Write-Error "✗ Terraform not found. Please install: https://www.terraform.io/downloads"
    exit 1
}

# Navigate to EKS terraform directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$eksPath = Join-Path $scriptPath "eks"

if (-not (Test-Path $eksPath)) {
    Write-Error "✗ EKS terraform directory not found at: $eksPath"
    exit 1
}

Push-Location $eksPath

try {
    # Initialize Terraform
    Write-Info "`nInitializing Terraform..."
    terraform init
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform init failed"
        exit 1
    }
    Write-Success "✓ Terraform initialized"

    # Create terraform.tfvars if it doesn't exist
    $tfvarsPath = "terraform.tfvars"
    if (-not (Test-Path $tfvarsPath)) {
        Write-Info "Creating terraform.tfvars with custom values..."
        @"
aws_region   = "$Region"
cluster_name = "$ClusterName"
"@ | Out-File -FilePath $tfvarsPath -Encoding utf8
        Write-Success "✓ Created terraform.tfvars"
    }

    # Destroy infrastructure if requested
    if ($Destroy) {
        Write-Warning "`nDESTROYING EKS INFRASTRUCTURE..."
        Write-Warning "This will remove all resources including the EKS cluster, VPC, and associated resources."
        
        if ($AutoApprove) {
            terraform destroy -auto-approve
        } else {
            terraform destroy
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "`n✓ EKS infrastructure destroyed successfully"
        } else {
            Write-Error "Terraform destroy failed"
        }
        exit $LASTEXITCODE
    }

    # Plan if requested
    if ($Plan) {
        Write-Info "`nCreating Terraform plan..."
        terraform plan -out=tfplan
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Terraform plan failed"
            exit 1
        }
        
        Write-Success "`n✓ Terraform plan created successfully"
        Write-Info "Review the plan above and run without -Plan flag to apply"
        exit 0
    }

    # Apply Terraform
    Write-Info "`nApplying Terraform configuration..."
    Write-Warning "This will create an EKS cluster and associated resources. This process takes 15-20 minutes."
    
    if ($AutoApprove) {
        terraform apply -auto-approve
    } else {
        terraform apply
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform apply failed"
        exit 1
    }
    
    Write-Success "`n✓ EKS infrastructure deployed successfully!"
    
    # Get outputs
    Write-Info "`nGetting deployment outputs..."
    $outputs = terraform output -json | ConvertFrom-Json
    
    Write-Success "`n=============================================="
    Write-Success "EKS Deployment Summary"
    Write-Success "=============================================="
    Write-Info "Cluster Name: $($outputs.cluster_name.value)"
    Write-Info "Region: $Region"
    Write-Info "Cluster Endpoint: $($outputs.cluster_endpoint.value)"
    Write-Info "VPC ID: $($outputs.vpc_id.value)"
    if ($outputs.ecr_repository_url.value) {
        Write-Info "ECR Repository: $($outputs.ecr_repository_url.value)"
    }
    Write-Info "CloudWatch Logs: $($outputs.cloudwatch_log_group_name.value)"
    Write-Info "S3 Logs Bucket: $($outputs.s3_logs_bucket.value)"
    Write-Success "=============================================="
    
    # Configure kubectl
    Write-Info "`nConfiguring kubectl..."
    $updateKubeconfigCmd = $outputs.update_kubeconfig_command.value
    Invoke-Expression $updateKubeconfigCmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✓ kubectl configured for EKS cluster"
        
        # Test connection
        Write-Info "`nTesting cluster connection..."
        kubectl get nodes
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Successfully connected to EKS cluster"
            
            # Check addon status
            Write-Info "`nChecking EKS addons..."
            kubectl get pods -n kube-system | Select-String -Pattern "ebs-csi|coredns|aws-load-balancer-controller"
        }
    }
    
    # Save outputs to file
    $outputsFile = "eks-outputs.json"
    $outputs | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputsFile -Encoding utf8
    Write-Info "`nOutputs saved to: $outputsFile"
    
    # Next steps
    Write-Info "`nNext Steps:"
    Write-Host "1. Deploy the application:" -ForegroundColor Gray
    Write-Host "   cd ../.." -ForegroundColor Gray
    Write-Host "   .\deploy-eks.ps1 -UpdateDependencies -Wait" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Monitor the cluster:" -ForegroundColor Gray
    Write-Host "   kubectl get nodes" -ForegroundColor Gray
    Write-Host "   kubectl get pods --all-namespaces" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Access CloudWatch Container Insights:" -ForegroundColor Gray
    Write-Host "   https://console.aws.amazon.com/cloudwatch/home?region=$Region#container-insights:infrastructure" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. View EKS Console:" -ForegroundColor Gray
    Write-Host "   https://console.aws.amazon.com/eks/home?region=$Region#/clusters/$ClusterName" -ForegroundColor Gray
    
} finally {
    Pop-Location
}

Write-Success "`nEKS infrastructure deployment complete! 🚀"