# validate-aks.ps1 - Validate AKS Terraform configuration
# Runs terraform fmt, validate, and AKS-specific checks

param(
    [switch]$Fix,
    [switch]$Detailed,
    [switch]$CheckAzure
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
Write-Success "AKS Terraform Configuration Validation"
Write-Success "=============================================="

$errors = 0
$warnings = 0

# Check prerequisites
Write-Info "Checking prerequisites..."

# Check Terraform
try {
    $tfVersion = terraform version -json | ConvertFrom-Json
    Write-Success "✓ Terraform version: $($tfVersion.terraform_version)"
} catch {
    Write-Error "✗ Terraform not found"
    exit 1
}

# Check Azure CLI if CheckAzure is specified
if ($CheckAzure) {
    try {
        $azVersion = az version --output json | ConvertFrom-Json
        Write-Success "✓ Azure CLI version: $($azVersion.'azure-cli')"
        
        # Check if logged in
        $account = az account show --output json | ConvertFrom-Json
        Write-Success "✓ Logged in to Azure: $($account.name)"
    } catch {
        Write-Error "✗ Azure CLI not available or not logged in"
        if ($CheckAzure) {
            $errors++
        }
    }
}

# Step 1: Format check
Write-Info "`nChecking Terraform formatting..."
if ($Fix) {
    $fmtOutput = terraform fmt -recursive 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✓ Formatting applied"
        if ($fmtOutput) {
            $fmtOutput | ForEach-Object { Write-Host "  Fixed: $_" -ForegroundColor Gray }
        }
    } else {
        Write-Error "✗ Formatting failed"
        $errors++
    }
} else {
    $fmtCheck = terraform fmt -check -recursive 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✓ All files properly formatted"
    } else {
        Write-Warning "⚠ Formatting issues found (use -Fix to correct):"
        $fmtCheck | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
        $warnings++
    }
}

# Step 2: Initialize
Write-Info "`nInitializing Terraform..."
terraform init -backend=false -upgrade=false > $null 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Success "✓ Terraform initialized"
} else {
    Write-Error "✗ Terraform init failed"
    $errors++
}

# Step 3: Validate
Write-Info "`nValidating configuration..."
if ($Detailed) {
    $validateOutput = terraform validate -json | ConvertFrom-Json
    if ($validateOutput.valid) {
        Write-Success "✓ Configuration is valid"
    } else {
        Write-Error "✗ Configuration validation failed:"
        $validateOutput.diagnostics | ForEach-Object {
            Write-Error "  $($_.summary)"
            if ($_.detail) { Write-Host "    $($_.detail)" -ForegroundColor Red }
        }
        $errors++
    }
} else {
    terraform validate > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✓ Configuration is valid"
    } else {
        Write-Error "✗ Configuration validation failed"
        $errors++
    }
}

# Step 4: AKS-specific checks
Write-Info "`nRunning AKS-specific checks..."

# Check for required variables
$requiredVars = @(
    "resource_group_name",
    "location", 
    "cluster_name",
    "kubernetes_version"
)

$varsContent = Get-Content -Path "variables.tf" -Raw
foreach ($var in $requiredVars) {
    if ($varsContent -match "variable\s+`"$var`"") {
        Write-Success "✓ Required variable '$var' defined"
    } else {
        Write-Error "✗ Required variable '$var' missing"
        $errors++
    }
}

# Check for Azure resource naming conventions
$nameChecks = @{
    "resource_group_name" = "^[a-zA-Z0-9._-]+$"
    "cluster_name" = "^[a-zA-Z0-9-]+$"
    "acr_name" = "^[a-zA-Z0-9]+$"
}

if (Test-Path "terraform.tfvars") {
    Write-Info "Checking terraform.tfvars naming conventions..."
    $tfvarsContent = Get-Content -Path "terraform.tfvars" -Raw
    
    foreach ($check in $nameChecks.GetEnumerator()) {
        if ($tfvarsContent -match "$($check.Key)\s*=\s*`"([^`"]+)`"") {
            $value = $matches[1]
            if ($value -match $check.Value) {
                Write-Success "✓ $($check.Key) naming convention valid"
            } else {
                Write-Warning "⚠ $($check.Key) '$value' may not follow Azure naming conventions"
                $warnings++
            }
        }
    }
}

# Check for Azure regions
$validRegions = @(
    "eastus", "eastus2", "westus", "westus2", "westus3",
    "northeurope", "westeurope", "centralus", "southcentralus",
    "australiaeast", "southeastasia", "eastasia", "uksouth",
    "japaneast", "brazilsouth", "francecentral", "canadacentral"
)

if (Test-Path "terraform.tfvars") {
    $tfvarsContent = Get-Content -Path "terraform.tfvars" -Raw
    if ($tfvarsContent -match "location\s*=\s*`"([^`"]+)`"") {
        $location = $matches[1]
        if ($validRegions -contains $location) {
            Write-Success "✓ Location '$location' is valid"
        } else {
            Write-Warning "⚠ Location '$location' may not be a valid Azure region"
            $warnings++
        }
    }
}

# Check for Kubernetes version format
if (Test-Path "terraform.tfvars") {
    $tfvarsContent = Get-Content -Path "terraform.tfvars" -Raw
    if ($tfvarsContent -match "kubernetes_version\s*=\s*`"([^`"]+)`"") {
        $k8sVersion = $matches[1]
        if ($k8sVersion -match "^\d+\.\d+\.\d+$") {
            Write-Success "✓ Kubernetes version '$k8sVersion' format valid"
        } else {
            Write-Warning "⚠ Kubernetes version '$k8sVersion' format may be invalid"
            $warnings++
        }
    }
}

# Step 5: Check for Azure-specific resources
Write-Info "`nChecking Azure resource configuration..."

$mainContent = Get-Content -Path "main.tf" -Raw
$azureResources = @(
    "azurerm_kubernetes_cluster",
    "azurerm_resource_group",
    "azurerm_virtual_network",
    "azurerm_log_analytics_workspace"
)

foreach ($resource in $azureResources) {
    if ($mainContent -match "resource\s+`"$resource`"") {
        Write-Success "✓ $resource configured"
    } else {
        Write-Warning "⚠ $resource not found in configuration"
        $warnings++
    }
}

# Step 6: Check for security best practices
Write-Info "`nChecking security configuration..."

$securityChecks = @(
    @{Pattern="azure_policy_enabled\s*=\s*true"; Description="Azure Policy enabled"},
    @{Pattern="enable_host_encryption\s*=\s*true"; Description="Host encryption enabled"},
    @{Pattern="microsoft_defender"; Description="Microsoft Defender configured"},
    @{Pattern="admin_enabled\s*=\s*false"; Description="ACR admin disabled"}
)

foreach ($check in $securityChecks) {
    if ($mainContent -match $check.Pattern) {
        Write-Success "✓ $($check.Description)"
    } else {
        Write-Warning "⚠ $($check.Description) not configured"
        $warnings++
    }
}

# Step 7: Check for monitoring
Write-Info "`nChecking monitoring configuration..."

$monitoringChecks = @(
    "azurerm_log_analytics_workspace",
    "azurerm_application_insights",
    "azurerm_monitor_diagnostic_setting",
    "oms_agent"
)

foreach ($check in $monitoringChecks) {
    if ($mainContent -match $check) {
        Write-Success "✓ $check configured"
    } else {
        Write-Warning "⚠ $check not found"
        $warnings++
    }
}

# Step 8: Check outputs
Write-Info "`nChecking outputs..."

if (Test-Path "outputs.tf") {
    $outputsContent = Get-Content -Path "outputs.tf" -Raw
    $requiredOutputs = @(
        "cluster_name",
        "resource_group_name",
        "get_credentials_command"
    )
    
    foreach ($output in $requiredOutputs) {
        if ($outputsContent -match "output\s+`"$output`"") {
            Write-Success "✓ Output '$output' defined"
        } else {
            Write-Warning "⚠ Output '$output' missing"
            $warnings++
        }
    }
} else {
    Write-Warning "⚠ No outputs.tf file found"
    $warnings++
}

# Final summary
Write-Info "`n=============================================="
Write-Info "AKS Validation Summary"
Write-Info "=============================================="

if ($errors -eq 0 -and $warnings -eq 0) {
    Write-Success "✅ All checks passed! AKS configuration is ready."
} elseif ($errors -eq 0) {
    Write-Warning "⚠️  Validation completed with $warnings warning(s)"
    Write-Warning "Configuration is valid but could be improved."
} else {
    Write-Error "❌ Validation failed with $errors error(s) and $warnings warning(s)"
    Write-Error "Please fix the errors before deployment."
    exit 1
}

# Next steps
Write-Info "`nNext Steps:"
if ($errors -eq 0) {
    Write-Host "1. Plan deployment: ..\deploy-aks-infra.ps1 -Plan" -ForegroundColor Gray
    Write-Host "2. Deploy: ..\deploy-aks-infra.ps1" -ForegroundColor Gray
    if ($CheckAzure) {
        Write-Host "3. Verify subscription: az account show" -ForegroundColor Gray
    }
} else {
    Write-Host "1. Fix errors reported above" -ForegroundColor Gray
    Write-Host "2. Run validation again: .\validate-aks.ps1" -ForegroundColor Gray
}

Write-Success "`nAKS validation complete! 🚀"