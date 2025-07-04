# validate-eks.ps1 - Validate EKS Terraform configuration
# Runs terraform fmt, validate, and EKS-specific checks

param(
    [switch]$Fix,
    [switch]$Detailed,
    [switch]$CheckAWS
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
Write-Success "EKS Terraform Configuration Validation"
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

# Check AWS CLI if CheckAWS is specified
if ($CheckAWS) {
    try {
        $awsVersion = aws --version 2>&1
        Write-Success "✓ AWS CLI: $awsVersion"
        
        # Check if credentials are configured
        $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
        Write-Success "✓ AWS credentials configured: $($identity.Arn)"
    } catch {
        Write-Error "✗ AWS CLI not available or credentials not configured"
        if ($CheckAWS) {
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

# Step 4: EKS-specific checks
Write-Info "`nRunning EKS-specific checks..."

# Check for required variables
$requiredVars = @(
    "aws_region",
    "cluster_name",
    "kubernetes_version",
    "node_instance_type"
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

# Check for AWS resource naming conventions
$nameChecks = @{
    "cluster_name" = "^[a-zA-Z0-9-]+$"
    "ecr_repository_name" = "^[a-z0-9-._/]+$"
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
                Write-Warning "⚠ $($check.Key) '$value' may not follow AWS naming conventions"
                $warnings++
            }
        }
    }
}

# Check for AWS regions
$validRegions = @(
    "us-east-1", "us-east-2", "us-west-1", "us-west-2",
    "eu-west-1", "eu-west-2", "eu-west-3", "eu-central-1",
    "ap-southeast-1", "ap-southeast-2", "ap-northeast-1", "ap-northeast-2",
    "ap-south-1", "ca-central-1", "sa-east-1"
)

if (Test-Path "terraform.tfvars") {
    $tfvarsContent = Get-Content -Path "terraform.tfvars" -Raw
    if ($tfvarsContent -match "aws_region\s*=\s*`"([^`"]+)`"") {
        $region = $matches[1]
        if ($validRegions -contains $region) {
            Write-Success "✓ Region '$region' is valid"
        } else {
            Write-Warning "⚠ Region '$region' may not be a valid AWS region"
            $warnings++
        }
    }
}

# Check for Kubernetes version format
if (Test-Path "terraform.tfvars") {
    $tfvarsContent = Get-Content -Path "terraform.tfvars" -Raw
    if ($tfvarsContent -match "kubernetes_version\s*=\s*`"([^`"]+)`"") {
        $k8sVersion = $matches[1]
        if ($k8sVersion -match "^\d+\.\d+$") {
            Write-Success "✓ Kubernetes version '$k8sVersion' format valid"
        } else {
            Write-Warning "⚠ Kubernetes version '$k8sVersion' format may be invalid for EKS"
            $warnings++
        }
    }
}

# Step 5: Check for AWS-specific resources
Write-Info "`nChecking AWS resource configuration..."

$mainContent = Get-Content -Path "main.tf" -Raw
$awsResources = @(
    "module.*eks",
    "module.*vpc",
    "aws_kms_key",
    "aws_cloudwatch_log_group",
    "aws_s3_bucket"
)

foreach ($resource in $awsResources) {
    if ($mainContent -match $resource) {
        Write-Success "✓ $resource configured"
    } else {
        Write-Warning "⚠ $resource not found in configuration"
        $warnings++
    }
}

# Step 6: Check for security best practices
Write-Info "`nChecking security configuration..."

$securityChecks = @(
    @{Pattern="enable_irsa\s*=\s*true"; Description="IRSA enabled"},
    @{Pattern="encryption_config"; Description="Encryption at rest configured"},
    @{Pattern="cluster_endpoint_private_access\s*=\s*true"; Description="Private API access enabled"},
    @{Pattern="enable_key_rotation\s*=\s*true"; Description="KMS key rotation enabled"}
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
    "aws_cloudwatch_log_group",
    "cluster_enabled_log_types",
    "enable_monitoring\s*=\s*true",
    "cloudwatch"
)

foreach ($check in $monitoringChecks) {
    if ($mainContent -match $check) {
        Write-Success "✓ $check configured"
    } else {
        Write-Warning "⚠ $check not found"
        $warnings++
    }
}

# Step 8: Check for required addons
Write-Info "`nChecking EKS addons..."

$requiredAddons = @(
    "aws-ebs-csi-driver",
    "coredns",
    "kube-proxy",
    "vpc-cni"
)

foreach ($addon in $requiredAddons) {
    if ($mainContent -match $addon) {
        Write-Success "✓ $addon configured"
    } else {
        Write-Warning "⚠ $addon not found in cluster_addons"
        $warnings++
    }
}

# Step 9: Check for Load Balancer Controller
Write-Info "`nChecking AWS Load Balancer Controller..."

if ($mainContent -match "aws_load_balancer_controller" -and $mainContent -match "helm_release") {
    Write-Success "✓ AWS Load Balancer Controller configured"
} else {
    Write-Warning "⚠ AWS Load Balancer Controller not found"
    $warnings++
}

# Step 10: Check outputs
Write-Info "`nChecking outputs..."

if (Test-Path "outputs.tf") {
    $outputsContent = Get-Content -Path "outputs.tf" -Raw
    $requiredOutputs = @(
        "cluster_name",
        "cluster_endpoint",
        "update_kubeconfig_command",
        "oidc_provider_arn"
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

# Step 11: Check for EC2 instance types
if (Test-Path "terraform.tfvars") {
    $tfvarsContent = Get-Content -Path "terraform.tfvars" -Raw
    if ($tfvarsContent -match "node_instance_type\s*=\s*`"([^`"]+)`"") {
        $instanceType = $matches[1]
        $validInstanceFamilies = @("t3", "t3a", "m5", "m5a", "m5n", "m5dn", "m6i", "c5", "c5n", "c5a", "r5", "r5a", "r5n")
        $family = $instanceType.Split('.')[0]
        
        if ($validInstanceFamilies -contains $family) {
            Write-Success "✓ Instance type '$instanceType' is valid"
        } else {
            Write-Warning "⚠ Instance type '$instanceType' may not be optimal for EKS"
            $warnings++
        }
    }
}

# Final summary
Write-Info "`n=============================================="
Write-Info "EKS Validation Summary"
Write-Info "=============================================="

if ($errors -eq 0 -and $warnings -eq 0) {
    Write-Success "✅ All checks passed! EKS configuration is ready."
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
    Write-Host "1. Plan deployment: ..\deploy-eks-infra.ps1 -Plan" -ForegroundColor Gray
    Write-Host "2. Deploy: ..\deploy-eks-infra.ps1" -ForegroundColor Gray
    if ($CheckAWS) {
        Write-Host "3. Verify credentials: aws sts get-caller-identity" -ForegroundColor Gray
    }
} else {
    Write-Host "1. Fix errors reported above" -ForegroundColor Gray
    Write-Host "2. Run validation again: .\validate-eks.ps1" -ForegroundColor Gray
}

Write-Success "`nEKS validation complete! 🚀"