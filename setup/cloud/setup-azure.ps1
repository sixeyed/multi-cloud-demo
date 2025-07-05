# setup-azure.ps1 - Configure Azure authentication and register providers
# Prerequisites: Azure CLI installed

param(
    [string]$SubscriptionName,
    [string]$SubscriptionId,
    [switch]$RegisterProviders,
    [switch]$Verify,
    [switch]$DeviceCode
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
Write-Success "Multi-Cloud Demo - Azure Setup"
Write-Success "=============================================="

# Check Azure CLI installation
Write-Info "`nChecking Azure CLI installation..."
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Success "✓ Azure CLI version: $($azVersion.'azure-cli')"
} catch {
    Write-Error "✗ Azure CLI not found. Please install it first:"
    Write-Info "macOS: brew install azure-cli"
    Write-Info "Windows: winget install Microsoft.AzureCLI"
    Write-Info "Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
    exit 1
}

# Login to Azure
Write-Info "`nChecking Azure authentication..."
try {
    $currentAccount = az account show --output json | ConvertFrom-Json
    Write-Success "✓ Already logged in to Azure account: $($currentAccount.name)"
    Write-Info "  Subscription: $($currentAccount.id)"
    Write-Info "  User: $($currentAccount.user.name)"
} catch {
    Write-Info "Logging in to Azure..."
    
    if ($DeviceCode) {
        az login --use-device-code
    } else {
        az login
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Azure login failed"
        exit 1
    }
    
    Write-Success "✓ Successfully logged in to Azure"
}

# Set subscription if specified
if ($SubscriptionName -or $SubscriptionId) {
    Write-Info "`nSetting Azure subscription..."
    
    if ($SubscriptionId) {
        az account set --subscription $SubscriptionId
        $identifier = $SubscriptionId
    } else {
        az account set --subscription $SubscriptionName
        $identifier = $SubscriptionName
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✓ Switched to subscription: $identifier"
    } else {
        Write-Error "✗ Failed to set subscription: $identifier"
        Write-Info "Available subscriptions:"
        az account list --query "[].{Name:name, ID:id, State:state}" --output table
        exit 1
    }
}

# Show current subscription
$currentAccount = az account show --output json | ConvertFrom-Json
Write-Info "`nCurrent Azure context:"
Write-Info "  Subscription: $($currentAccount.name)"
Write-Info "  ID: $($currentAccount.id)"
Write-Info "  Tenant: $($currentAccount.tenantId)"

# Register Azure providers
if ($RegisterProviders -or -not $PSBoundParameters.ContainsKey('RegisterProviders')) {
    Write-Info "`nRegistering required Azure resource providers..."
    
    $providers = @(
        "Microsoft.ContainerService",
        "Microsoft.OperationsManagement", 
        "Microsoft.OperationalInsights",
        "Microsoft.Insights",
        "Microsoft.Storage",
        "Microsoft.Network",
        "Microsoft.ContainerRegistry",
        "Microsoft.Authorization",
        "Microsoft.Compute",
        "Microsoft.KeyVault"
    )
    
    foreach ($provider in $providers) {
        Write-Info "Registering $provider..."
        az provider register --namespace $provider
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ $provider registration initiated"
        } else {
            Write-Warning "⚠ Failed to register $provider"
        }
    }
    
    Write-Info "`nProvider registration may take several minutes to complete."
    Write-Info "You can check status with: az provider show --namespace <provider-name> --query registrationState"
}

# Verification
if ($Verify -or -not $PSBoundParameters.ContainsKey('Verify')) {
    Write-Info "`nVerifying Azure setup..."
    
    # Test basic Azure CLI functionality
    try {
        $subscriptions = az account list --query "[].{Name:name, State:state}" --output json | ConvertFrom-Json
        $activeSubscriptions = $subscriptions | Where-Object { $_.State -eq "Enabled" }
        
        Write-Success "✓ Azure CLI authentication working"
        Write-Info "  Available subscriptions: $($activeSubscriptions.Count)"
        
        # Test resource group operations (requires Contributor role)
        $testRgName = "test-access-$(Get-Random -Minimum 1000 -Maximum 9999)"
        Write-Info "Testing resource group creation permissions..."
        
        az group create --name $testRgName --location "westeurope" --output none 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Resource group creation permissions verified"
            az group delete --name $testRgName --yes --no-wait --output none 2>$null
        } else {
            Write-Warning "⚠ Resource group creation failed - check permissions"
        }
        
    } catch {
        Write-Error "✗ Azure CLI verification failed"
        exit 1
    }
    
    # Check key provider registration status
    Write-Info "`nChecking critical provider registration status..."
    $criticalProviders = @("Microsoft.ContainerService", "Microsoft.OperationsManagement")
    
    foreach ($provider in $criticalProviders) {
        try {
            $status = az provider show --namespace $provider --query registrationState --output tsv
            if ($status -eq "Registered") {
                Write-Success "✓ $provider: Registered"
            } elseif ($status -eq "Registering") {
                Write-Warning "⚠ $provider: Still registering (this is normal)"
            } else {
                Write-Error "✗ $provider: $status"
            }
        } catch {
            Write-Warning "⚠ Could not check $provider status"
        }
    }
}

# Create service principal for Terraform (optional)
$createSP = Read-Host "`nWould you like to create a service principal for Terraform automation? (y/N)"
if ($createSP -eq "y" -or $createSP -eq "Y") {
    Write-Info "`nCreating service principal for Terraform..."
    
    $spName = "terraform-multi-cloud-demo"
    $subscriptionId = $currentAccount.id
    
    try {
        $sp = az ad sp create-for-rbac --name $spName --role Contributor --scopes "/subscriptions/$subscriptionId" --output json | ConvertFrom-Json
        
        Write-Success "✓ Service principal created successfully"
        Write-Info "`nService Principal Details (save these securely):"
        Write-Host "  Application ID: $($sp.appId)" -ForegroundColor Yellow
        Write-Host "  Secret: $($sp.password)" -ForegroundColor Yellow
        Write-Host "  Tenant ID: $($sp.tenant)" -ForegroundColor Yellow
        Write-Host "  Subscription ID: $subscriptionId" -ForegroundColor Yellow
        
        Write-Info "`nTo use this service principal with Terraform, set these environment variables:"
        Write-Host "export ARM_CLIENT_ID='$($sp.appId)'" -ForegroundColor Gray
        Write-Host "export ARM_CLIENT_SECRET='$($sp.password)'" -ForegroundColor Gray
        Write-Host "export ARM_SUBSCRIPTION_ID='$subscriptionId'" -ForegroundColor Gray
        Write-Host "export ARM_TENANT_ID='$($sp.tenant)'" -ForegroundColor Gray
        
    } catch {
        Write-Warning "⚠ Service principal creation failed. You can create one later if needed."
    }
}

# Next steps
Write-Success "`n🎉 Azure setup complete!"
Write-Info "`nNext Steps:"
Write-Host "1. Wait for provider registration to complete (check with az provider show commands above)" -ForegroundColor Gray
Write-Host "2. Deploy AKS infrastructure:" -ForegroundColor Gray
Write-Host "   cd ../../terraform" -ForegroundColor Gray
Write-Host "   pwsh ./deploy-aks-infra.ps1 -Plan" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Or set up AWS for multi-cloud deployment:" -ForegroundColor Gray
Write-Host "   pwsh ./setup-aws.ps1" -ForegroundColor Gray

Write-Info "`nUseful Azure commands:"
Write-Host "  az account list              # List subscriptions" -ForegroundColor Gray
Write-Host "  az account set --subscription <id>  # Switch subscription" -ForegroundColor Gray
Write-Host "  az group list                # List resource groups" -ForegroundColor Gray
Write-Host "  az provider list --query \"[?registrationState=='Registered']\"  # List registered providers" -ForegroundColor Gray