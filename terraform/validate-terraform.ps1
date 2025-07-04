# validate-terraform.ps1 - Validate Terraform configurations for both AKS and EKS
# Runs terraform fmt, validate, and checks for common issues

param(
    [ValidateSet("all", "aks", "eks")]
    [string]$Environment = "all",
    [switch]$Fix,
    [switch]$Detailed
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
Write-Success "================================================"
Write-Success "Terraform Configuration Validation"
Write-Success "================================================"

# Check prerequisites
Write-Info "Checking prerequisites..."

# Check Terraform
try {
    $tfVersion = terraform version -json | ConvertFrom-Json
    Write-Success "✓ Terraform version: $($tfVersion.terraform_version)"
    
    # Check minimum version
    $minVersion = [Version]"1.3.0"
    $currentVersion = [Version]$tfVersion.terraform_version.Split('-')[0]
    
    if ($currentVersion -lt $minVersion) {
        Write-Warning "⚠ Terraform version $currentVersion is below recommended minimum $minVersion"
    }
} catch {
    Write-Error "✗ Terraform not found. Please install: https://www.terraform.io/downloads"
    exit 1
}

# Check tflint if available
$tflintAvailable = $false
try {
    $null = tflint --version 2>$null
    $tflintAvailable = $true
    Write-Success "✓ tflint is available for additional validation"
} catch {
    Write-Info "ℹ tflint not found (optional). Install for additional validation: https://github.com/terraform-linters/tflint"
}

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$totalErrors = 0
$totalWarnings = 0

function Validate-TerraformConfig {
    param(
        [string]$ConfigName,
        [string]$ConfigPath
    )
    
    Write-Info "`n================================================"
    Write-Info "Validating $ConfigName configuration"
    Write-Info "================================================"
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "✗ Configuration directory not found: $ConfigPath"
        return 1
    }
    
    Push-Location $ConfigPath
    $errors = 0
    
    try {
        # Step 1: Check for .tf files
        $tfFiles = Get-ChildItem -Filter "*.tf" -File
        if ($tfFiles.Count -eq 0) {
            Write-Error "✗ No Terraform files found in $ConfigPath"
            return 1
        }
        Write-Success "✓ Found $($tfFiles.Count) Terraform files"
        
        # Step 2: Terraform fmt
        Write-Info "`nChecking formatting..."
        if ($Fix) {
            Write-Info "Running terraform fmt (fixing issues)..."
            $fmtOutput = terraform fmt -recursive 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✓ Formatting applied successfully"
                if ($fmtOutput) {
                    Write-Info "  Fixed files:"
                    $fmtOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
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
                $fmtCheck | Where-Object { $_ -ne "" } | ForEach-Object { 
                    Write-Host "    $_" -ForegroundColor Yellow 
                }
                $totalWarnings++
            }
        }
        
        # Step 3: Terraform init
        Write-Info "`nInitializing Terraform..."
        $initOutput = terraform init -backend=false -upgrade=false 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Terraform initialized"
        } else {
            Write-Error "✗ Terraform init failed:"
            $initOutput | Select-Object -Last 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
            $errors++
            return $errors
        }
        
        # Step 4: Terraform validate
        Write-Info "`nValidating configuration..."
        if ($Detailed) {
            $validateOutput = terraform validate -json | ConvertFrom-Json
            if ($validateOutput.valid) {
                Write-Success "✓ Configuration is valid"
            } else {
                Write-Error "✗ Configuration validation failed:"
                $validateOutput.diagnostics | ForEach-Object {
                    Write-Error "  $($_.summary)"
                    if ($_.detail) {
                        Write-Host "    $($_.detail)" -ForegroundColor Red
                    }
                    if ($_.range) {
                        Write-Host "    File: $($_.range.filename):$($_.range.start.line)" -ForegroundColor Red
                    }
                }
                $errors++
            }
        } else {
            $validateOutput = terraform validate 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✓ Configuration is valid"
            } else {
                Write-Error "✗ Configuration validation failed:"
                $validateOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
                $errors++
            }
        }
        
        # Step 5: Check for required variables
        Write-Info "`nChecking variables..."
        $varsFile = Get-Item -Path "variables.tf" -ErrorAction SilentlyContinue
        if ($varsFile) {
            $requiredVars = Select-String -Path "variables.tf" -Pattern 'variable\s+"([^"]+)"' -AllMatches
            $varCount = $requiredVars.Matches.Count
            Write-Success "✓ Found $varCount variable definitions"
            
            # Check for example tfvars
            if (Test-Path "terraform.tfvars.example") {
                Write-Success "✓ Example tfvars file present"
            } else {
                Write-Warning "⚠ No terraform.tfvars.example file found"
                $totalWarnings++
            }
            
            # Check if terraform.tfvars exists (for info only)
            if (Test-Path "terraform.tfvars") {
                Write-Info "ℹ terraform.tfvars exists (not tracked in git)"
            }
        }
        
        # Step 6: Check for outputs
        $outputsFile = Get-Item -Path "outputs.tf" -ErrorAction SilentlyContinue
        if ($outputsFile) {
            $outputs = Select-String -Path "outputs.tf" -Pattern 'output\s+"([^"]+)"' -AllMatches
            $outputCount = $outputs.Matches.Count
            Write-Success "✓ Found $outputCount output definitions"
        } else {
            Write-Warning "⚠ No outputs.tf file found"
            $totalWarnings++
        }
        
        # Step 7: Check providers
        Write-Info "`nChecking providers..."
        $providers = terraform providers 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Provider configuration valid"
            if ($Detailed) {
                Write-Info "  Required providers:"
                $providers | Where-Object { $_ -match "provider" } | ForEach-Object {
                    Write-Host "    $_" -ForegroundColor Gray
                }
            }
        } else {
            Write-Error "✗ Provider configuration issues"
            $errors++
        }
        
        # Step 8: Run tflint if available
        if ($tflintAvailable) {
            Write-Info "`nRunning tflint..."
            $tflintOutput = tflint --format=compact 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✓ tflint validation passed"
            } else {
                Write-Warning "⚠ tflint found issues:"
                $tflintOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
                $totalWarnings++
            }
        }
        
        # Step 9: Check for sensitive data
        Write-Info "`nChecking for potential sensitive data..."
        $sensitivePatterns = @(
            "password\s*=\s*[`"'][^`"']+[`"']",
            "secret\s*=\s*[`"'][^`"']+[`"']",
            "key\s*=\s*[`"'][^`"']+[`"']"
        )
        
        $sensitiveFound = $false
        foreach ($pattern in $sensitivePatterns) {
            $matches = Get-ChildItem -Filter "*.tf" | Select-String -Pattern $pattern
            if ($matches) {
                $sensitiveFound = $true
                Write-Warning "⚠ Potential sensitive data found:"
                $matches | ForEach-Object {
                    Write-Host "    $($_.Filename):$($_.LineNumber) - $($_.Line.Trim())" -ForegroundColor Yellow
                }
                $totalWarnings++
            }
        }
        
        if (-not $sensitiveFound) {
            Write-Success "✓ No hardcoded sensitive data detected"
        }
        
        # Summary for this config
        if ($errors -eq 0) {
            Write-Success "`n✓ $ConfigName validation completed successfully"
        } else {
            Write-Error "`n✗ $ConfigName validation failed with $errors error(s)"
        }
        
    } finally {
        Pop-Location
    }
    
    return $errors
}

# Validate configurations based on parameter
$configs = @()
switch ($Environment) {
    "all" {
        $configs = @(
            @{Name="AKS"; Path=Join-Path $scriptPath "aks"},
            @{Name="EKS"; Path=Join-Path $scriptPath "eks"}
        )
    }
    "aks" {
        $configs = @(@{Name="AKS"; Path=Join-Path $scriptPath "aks"})
    }
    "eks" {
        $configs = @(@{Name="EKS"; Path=Join-Path $scriptPath "eks"})
    }
}

# Run validation for each configuration
foreach ($config in $configs) {
    $errors = Validate-TerraformConfig -ConfigName $config.Name -ConfigPath $config.Path
    $totalErrors += $errors
}

# Final summary
Write-Info "`n================================================"
Write-Info "Validation Summary"
Write-Info "================================================"

if ($totalErrors -eq 0 -and $totalWarnings -eq 0) {
    Write-Success "✅ All validation checks passed!"
    Write-Success "Your Terraform configurations are ready for deployment."
} elseif ($totalErrors -eq 0) {
    Write-Warning "⚠️  Validation completed with $totalWarnings warning(s)"
    Write-Warning "The configurations are valid but could be improved."
} else {
    Write-Error "❌ Validation failed with $totalErrors error(s) and $totalWarnings warning(s)"
    Write-Error "Please fix the errors before attempting deployment."
    exit 1
}

# Provide next steps
Write-Info "`nNext Steps:"
if ($totalErrors -eq 0) {
    Write-Host "1. Deploy infrastructure:" -ForegroundColor Gray
    Write-Host "   .\deploy-aks-infra.ps1 -Plan    # Review AKS changes" -ForegroundColor Gray
    Write-Host "   .\deploy-eks-infra.ps1 -Plan    # Review EKS changes" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Apply configurations:" -ForegroundColor Gray
    Write-Host "   .\deploy-aks-infra.ps1          # Deploy AKS" -ForegroundColor Gray
    Write-Host "   .\deploy-eks-infra.ps1          # Deploy EKS" -ForegroundColor Gray
} else {
    Write-Host "1. Fix the errors reported above" -ForegroundColor Gray
    Write-Host "2. Run validation again: .\validate-terraform.ps1" -ForegroundColor Gray
    Write-Host "3. Use -Fix flag to auto-format: .\validate-terraform.ps1 -Fix" -ForegroundColor Gray
}

if (-not $tflintAvailable) {
    Write-Host ""
    Write-Host "Consider installing tflint for additional validation:" -ForegroundColor Gray
    Write-Host "  https://github.com/terraform-linters/tflint" -ForegroundColor Gray
}