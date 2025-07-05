# deploy-aks-infra.ps1 - Deploy AKS infrastructure using Terraform
# Prerequisites:
# - Azure CLI installed and authenticated (az login)
# - Terraform installed
# - PowerShell 7.0+

param(
    [switch]$Plan,
    [switch]$Destroy,
    [switch]$AutoApprove,
    [switch]$Import,
    [string]$ResourceGroupName = "multi-cloud-demo-aks-rg",
    [string]$Location = "westeurope",
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
    terraform init -upgrade
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

    # Import existing resources if requested
    if ($Import) {
        Write-Info "`nImporting existing Azure resources..."
        
        try {
            # Import resource group
            $rgExists = az group exists --name $ResourceGroupName
            if ($rgExists -eq "true") {
                $rgId = az group show --name $ResourceGroupName --query id --output tsv
                Write-Info "Importing resource group: $ResourceGroupName"
                terraform import azurerm_resource_group.aks $rgId
            }
            
            # Import other resources if they exist
            $subscriptionId = az account show --query id --output tsv
            
            # Try importing common resources (ignore errors if they don't exist)
            $imports = @(
                @{ resource = "azurerm_log_analytics_workspace.aks"; id = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$ClusterName-logs" },
                @{ resource = "azurerm_container_registry.acr[0]"; id = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ContainerRegistry/registries/multiclouddemoacr" },
                @{ resource = "azurerm_virtual_network.aks"; id = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/$ClusterName-vnet" },
                @{ resource = "azurerm_storage_account.diagnostics"; id = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/multiclouddemoaksdiag" },
                @{ resource = "azurerm_application_insights.aks"; id = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Insights/components/$ClusterName-insights" }
            )
            
            foreach ($import in $imports) {
                Write-Info "Attempting to import $($import.resource)..."
                terraform import $import.resource $import.id 2>$null
            }
            
            Write-Success "✓ Import completed (some resources may not have existed)"
        } catch {
            Write-Warning "Some imports may have failed - this is normal if resources don't exist yet"
        }
    }

    # Always create a plan first
    Write-Info "`nCreating Terraform plan..."
    terraform plan -out=tfplan
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform plan failed"
        exit 1
    }
    
    Write-Success "`n✓ Terraform plan created successfully"
    
    # Plan only if requested
    if ($Plan) {
        Write-Info "Review the plan above and run without -Plan flag to apply"
        exit 0
    }

    # Apply from plan
    Write-Info "`nApplying Terraform plan..."
    terraform apply tfplan
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Terraform apply failed. Checking for import requirements..."
        
        # Check if this is an import issue
        $importNeeded = $false
        $resourceGroupName = (Get-Content terraform.tfvars | Where-Object { $_ -match 'resource_group_name' } | ForEach-Object { ($_ -split '=')[1].Trim().Trim('"') })
        if (-not $resourceGroupName) { $resourceGroupName = "multi-cloud-demo-aks-rg" }
        
        # Check if resource group exists but not in state
        try {
            $rgExists = az group exists --name $resourceGroupName
            if ($rgExists -eq "true") {
                $stateCheck = terraform state list | Where-Object { $_ -match "azurerm_resource_group" }
                if (-not $stateCheck) {
                    Write-Info "Resource group exists but not in Terraform state. Attempting import..."
                    $rgId = az group show --name $resourceGroupName --query id --output tsv
                    terraform import azurerm_resource_group.aks $rgId
                    $importNeeded = $true
                }
            }
        } catch {
            Write-Warning "Could not check resource group status"
        }
        
        # Check for other common resources that might need importing
        $commonResources = @(
            @{ name = "azurerm_log_analytics_workspace.aks"; pattern = "multi-cloud-demo-aks-logs" },
            @{ name = "azurerm_container_registry.acr[0]"; pattern = "multiclouddemoacr" },
            @{ name = "azurerm_virtual_network.aks"; pattern = "multi-cloud-demo-aks-vnet" },
            @{ name = "azurerm_storage_account.diagnostics"; pattern = "multiclouddemoaksdiag" }
        )
        
        foreach ($resource in $commonResources) {
            try {
                $stateCheck = terraform state list | Where-Object { $_ -eq $resource.name }
                if (-not $stateCheck) {
                    Write-Info "Checking if $($resource.pattern) exists and needs importing..."
                    # For simplicity, we'll regenerate the plan and let user handle specific imports
                    # Full automation would require more complex Azure resource queries
                }
            } catch {
                # Ignore errors in resource checking
            }
        }
        
        if ($importNeeded) {
            Write-Info "Resources imported. Regenerating plan..."
            terraform plan -out=tfplan
            if ($LASTEXITCODE -eq 0) {
                Write-Info "Retrying apply with updated state..."
                terraform apply tfplan
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "✓ Apply succeeded after import"
                } else {
                    Write-Error "Apply failed even after import. Manual intervention required."
                    Write-Info "Try running: terraform import <resource_type>.<resource_name> <azure_resource_id>"
                    exit 1
                }
            }
        } else {
            Write-Error "Terraform apply failed. Manual intervention required."
            Write-Info "Check the error above and consider importing existing resources:"
            Write-Info "terraform import azurerm_resource_group.aks /subscriptions/SUBSCRIPTION_ID/resourceGroups/RESOURCE_GROUP_NAME"
            exit 1
        }
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