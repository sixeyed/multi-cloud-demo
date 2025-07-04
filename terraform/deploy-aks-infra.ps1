# deploy-aks-infra.ps1 - Deploy AKS infrastructure using Terraform
# Prerequisites:
# - Azure CLI installed and authenticated (az login)
# - Terraform installed
# - PowerShell 7.0+

param(
    [switch]$Plan,
    [switch]$Destroy,
    [switch]$AutoApprove,
    [string]$ResourceGroupName = "multi-cloud-demo-aks-rg",
    [string]$Location = "eastus",
    [string]$ClusterName = "multi-cloud-demo-aks"
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
Write-Success "AKS Infrastructure Deployment with Terraform"
Write-Success "=============================================="

# Check prerequisites
Write-Info "Checking prerequisites..."

# Check Azure CLI
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Success "✓ Azure CLI version: $($azVersion.'azure-cli')"
} catch {
    Write-Error "✗ Azure CLI not found. Please install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Check if logged in to Azure
try {
    $account = az account show --output json | ConvertFrom-Json
    Write-Success "✓ Logged in to Azure account: $($account.name)"
    Write-Info "  Subscription: $($account.id)"
} catch {
    Write-Error "✗ Not logged in to Azure. Please run: az login"
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

# Navigate to AKS terraform directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$aksPath = Join-Path $scriptPath "aks"

if (-not (Test-Path $aksPath)) {
    Write-Error "✗ AKS terraform directory not found at: $aksPath"
    exit 1
}

Push-Location $aksPath

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
resource_group_name = "$ResourceGroupName"
location           = "$Location"
cluster_name       = "$ClusterName"
"@ | Out-File -FilePath $tfvarsPath -Encoding utf8
        Write-Success "✓ Created terraform.tfvars"
    }

    # Destroy infrastructure if requested
    if ($Destroy) {
        Write-Warning "`nDESTROYING AKS INFRASTRUCTURE..."
        
        if ($AutoApprove) {
            terraform destroy -auto-approve
        } else {
            terraform destroy
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "`n✓ AKS infrastructure destroyed successfully"
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
    
    if ($AutoApprove) {
        terraform apply -auto-approve
    } else {
        terraform apply
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform apply failed"
        exit 1
    }
    
    Write-Success "`n✓ AKS infrastructure deployed successfully!"
    
    # Get outputs
    Write-Info "`nGetting deployment outputs..."
    $outputs = terraform output -json | ConvertFrom-Json
    
    Write-Success "`n=============================================="
    Write-Success "AKS Deployment Summary"
    Write-Success "=============================================="
    Write-Info "Cluster Name: $($outputs.cluster_name.value)"
    Write-Info "Resource Group: $($outputs.resource_group_name.value)"
    Write-Info "Location: $Location"
    if ($outputs.acr_login_server.value) {
        Write-Info "ACR Login Server: $($outputs.acr_login_server.value)"
    }
    Write-Info "Log Analytics Workspace: Created"
    Write-Info "Application Insights: Created"
    Write-Success "=============================================="
    
    # Configure kubectl
    Write-Info "`nConfiguring kubectl..."
    $getCredsCmd = $outputs.get_credentials_command.value
    Invoke-Expression $getCredsCmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✓ kubectl configured for AKS cluster"
        
        # Test connection
        Write-Info "`nTesting cluster connection..."
        kubectl get nodes
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Successfully connected to AKS cluster"
        }
    }
    
    # Save outputs to file
    $outputsFile = "aks-outputs.json"
    $outputs | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputsFile -Encoding utf8
    Write-Info "`nOutputs saved to: $outputsFile"
    
    # Next steps
    Write-Info "`nNext Steps:"
    Write-Host "1. Deploy the application:" -ForegroundColor Gray
    Write-Host "   cd ../.." -ForegroundColor Gray
    Write-Host "   .\deploy-aks.ps1 -UpdateDependencies -Wait" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Monitor the cluster:" -ForegroundColor Gray
    Write-Host "   kubectl get nodes" -ForegroundColor Gray
    Write-Host "   kubectl get pods --all-namespaces" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Access Azure Portal:" -ForegroundColor Gray
    Write-Host "   https://portal.azure.com/#resource/subscriptions/$($account.id)/resourceGroups/$ResourceGroupName/providers/Microsoft.ContainerService/managedClusters/$ClusterName/overview" -ForegroundColor Gray
    
} finally {
    Pop-Location
}

Write-Success "`nAKS infrastructure deployment complete! 🚀"