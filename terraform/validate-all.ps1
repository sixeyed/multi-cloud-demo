# validate-all.ps1 - Run comprehensive validation on all Terraform configurations
# This script runs all validation checks across both AKS and EKS configurations

param(
    [switch]$Fix,
    [switch]$CheckCloud,
    [switch]$Fast
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
Write-Success "Multi-Cloud Terraform Validation Suite"
Write-Success "=============================================="

$startTime = Get-Date
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Summary tracking
$results = @{
    Overall = @{ Passed = 0; Failed = 0; Warnings = 0 }
    AKS = @{ Passed = 0; Failed = 0; Warnings = 0 }
    EKS = @{ Passed = 0; Failed = 0; Warnings = 0 }
    General = @{ Passed = 0; Failed = 0; Warnings = 0 }
}

Write-Info "Starting comprehensive validation at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
if ($Fast) {
    Write-Info "Running in fast mode (skipping cloud connectivity checks)"
}

# Step 1: Run general validation
Write-Info "`n🔍 Running general Terraform validation..."
try {
    $params = @()
    if ($Fix) { $params += "-Fix" }
    if (-not $Fast) { $params += "-Detailed" }
    
    $generalValidation = & "$scriptPath\validate-terraform.ps1" -Environment "all" @params
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✅ General validation passed"
        $results.General.Passed++
    } else {
        Write-Error "❌ General validation failed"
        $results.General.Failed++
    }
} catch {
    Write-Error "❌ General validation error: $($_.Exception.Message)"
    $results.General.Failed++
}

# Step 2: Validate AKS configuration
Write-Info "`n🔍 Running AKS-specific validation..."
$aksPath = Join-Path $scriptPath "aks"
if (Test-Path $aksPath) {
    Push-Location $aksPath
    try {
        $params = @()
        if ($Fix) { $params += "-Fix" }
        if ($CheckCloud -and -not $Fast) { $params += "-CheckAzure" }
        if (-not $Fast) { $params += "-Detailed" }
        
        $aksValidation = & ".\validate-aks.ps1" @params
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✅ AKS validation passed"
            $results.AKS.Passed++
        } else {
            Write-Error "❌ AKS validation failed"
            $results.AKS.Failed++
        }
    } catch {
        Write-Error "❌ AKS validation error: $($_.Exception.Message)"
        $results.AKS.Failed++
    } finally {
        Pop-Location
    }
} else {
    Write-Warning "⚠️ AKS directory not found"
    $results.AKS.Warnings++
}

# Step 3: Validate EKS configuration
Write-Info "`n🔍 Running EKS-specific validation..."
$eksPath = Join-Path $scriptPath "eks"
if (Test-Path $eksPath) {
    Push-Location $eksPath
    try {
        $params = @()
        if ($Fix) { $params += "-Fix" }
        if ($CheckCloud -and -not $Fast) { $params += "-CheckAWS" }
        if (-not $Fast) { $params += "-Detailed" }
        
        $eksValidation = & ".\validate-eks.ps1" @params
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✅ EKS validation passed"
            $results.EKS.Passed++
        } else {
            Write-Error "❌ EKS validation failed"
            $results.EKS.Failed++
        }
    } catch {
        Write-Error "❌ EKS validation error: $($_.Exception.Message)"
        $results.EKS.Failed++
    } finally {
        Pop-Location
    }
} else {
    Write-Warning "⚠️ EKS directory not found"
    $results.EKS.Warnings++
}

# Step 4: Additional cross-environment checks
if (-not $Fast) {
    Write-Info "`n🔍 Running cross-environment validation..."
    
    # Check for consistent naming patterns
    $aksVars = if (Test-Path "aks/terraform.tfvars") { Get-Content "aks/terraform.tfvars" -Raw } else { "" }
    $eksVars = if (Test-Path "eks/terraform.tfvars") { Get-Content "eks/terraform.tfvars" -Raw } else { "" }
    
    # Check for consistent tagging
    if ($aksVars -match 'tags\s*=' -and $eksVars -match 'tags\s*=') {
        Write-Success "✅ Both environments have tagging configured"
        $results.General.Passed++
    } elseif ($aksVars -match 'tags\s*=' -or $eksVars -match 'tags\s*=') {
        Write-Warning "⚠️ Inconsistent tagging across environments"
        $results.General.Warnings++
    }
    
    # Check for monitoring configuration
    $aksMain = if (Test-Path "aks/main.tf") { Get-Content "aks/main.tf" -Raw } else { "" }
    $eksMain = if (Test-Path "eks/main.tf") { Get-Content "eks/main.tf" -Raw } else { "" }
    
    $aksMonitoring = $aksMain -match "log_analytics|application_insights|monitor"
    $eksMonitoring = $eksMain -match "cloudwatch|container_insights"
    
    if ($aksMonitoring -and $eksMonitoring) {
        Write-Success "✅ Both environments have monitoring configured"
        $results.General.Passed++
    } else {
        Write-Warning "⚠️ Monitoring configuration may be missing"
        $results.General.Warnings++
    }
}

# Step 5: Check for security best practices
if (-not $Fast) {
    Write-Info "`n🔍 Running security validation..."
    
    # Check .gitignore
    if (Test-Path ".gitignore") {
        $gitignoreContent = Get-Content ".gitignore" -Raw
        $securityPatterns = @("*.tfvars", "*.tfstate", ".terraform/")
        $foundPatterns = 0
        
        foreach ($pattern in $securityPatterns) {
            if ($gitignoreContent -match [regex]::Escape($pattern)) {
                $foundPatterns++
            }
        }
        
        if ($foundPatterns -eq $securityPatterns.Count) {
            Write-Success "✅ .gitignore properly configured for security"
            $results.General.Passed++
        } else {
            Write-Warning "⚠️ .gitignore may expose sensitive Terraform files"
            $results.General.Warnings++
        }
    } else {
        Write-Warning "⚠️ No .gitignore found in terraform directory"
        $results.General.Warnings++
    }
}

# Calculate totals
$totalPassed = $results.General.Passed + $results.AKS.Passed + $results.EKS.Passed
$totalFailed = $results.General.Failed + $results.AKS.Failed + $results.EKS.Failed
$totalWarnings = $results.General.Warnings + $results.AKS.Warnings + $results.EKS.Warnings

$endTime = Get-Date
$duration = $endTime - $startTime

# Final summary
Write-Info "`n=============================================="
Write-Info "Validation Suite Summary"
Write-Info "=============================================="

Write-Info "Duration: $([math]::Round($duration.TotalSeconds, 1)) seconds"
Write-Info ""

# Results table
Write-Host "| Component | Passed | Failed | Warnings |" -ForegroundColor White
Write-Host "|-----------|--------|--------|----------|" -ForegroundColor White
Write-Host "| General   | $($results.General.Passed.ToString().PadLeft(6)) | $($results.General.Failed.ToString().PadLeft(6)) | $($results.General.Warnings.ToString().PadLeft(8)) |" -ForegroundColor White
Write-Host "| AKS       | $($results.AKS.Passed.ToString().PadLeft(6)) | $($results.AKS.Failed.ToString().PadLeft(6)) | $($results.AKS.Warnings.ToString().PadLeft(8)) |" -ForegroundColor White
Write-Host "| EKS       | $($results.EKS.Passed.ToString().PadLeft(6)) | $($results.EKS.Failed.ToString().PadLeft(6)) | $($results.EKS.Warnings.ToString().PadLeft(8)) |" -ForegroundColor White
Write-Host "|-----------|--------|--------|----------|" -ForegroundColor White
Write-Host "| **Total** | $($totalPassed.ToString().PadLeft(6)) | $($totalFailed.ToString().PadLeft(6)) | $($totalWarnings.ToString().PadLeft(8)) |" -ForegroundColor White

Write-Info ""

# Overall status
if ($totalFailed -eq 0 -and $totalWarnings -eq 0) {
    Write-Success "🎉 ALL VALIDATION CHECKS PASSED!"
    Write-Success "Your multi-cloud Terraform configurations are ready for deployment."
    $exitCode = 0
} elseif ($totalFailed -eq 0) {
    Write-Warning "⚠️  VALIDATION COMPLETED WITH WARNINGS"
    Write-Warning "Configurations are valid but could be improved ($totalWarnings warnings)."
    $exitCode = 0
} else {
    Write-Error "❌ VALIDATION FAILED"
    Write-Error "Found $totalFailed error(s) and $totalWarnings warning(s). Please fix before deployment."
    $exitCode = 1
}

# Recommendations
if ($totalFailed -gt 0 -or $totalWarnings -gt 0) {
    Write-Info "`nRecommendations:"
    
    if ($totalFailed -gt 0) {
        Write-Host "1. Fix all errors before attempting deployment" -ForegroundColor Red
        Write-Host "2. Run validation again: .\validate-all.ps1" -ForegroundColor Gray
    }
    
    if ($totalWarnings -gt 0) {
        Write-Host "3. Review warnings for security and best practices" -ForegroundColor Yellow
        Write-Host "4. Consider using -Fix flag to auto-resolve formatting issues" -ForegroundColor Gray
    }
    
    if (-not $CheckCloud) {
        Write-Host "5. Run with -CheckCloud to verify cloud provider connectivity" -ForegroundColor Gray
    }
}

# Next steps
if ($totalFailed -eq 0) {
    Write-Info "`nNext Steps:"
    Write-Host "1. Plan deployments:" -ForegroundColor Gray
    Write-Host "   .\deploy-aks-infra.ps1 -Plan" -ForegroundColor Gray
    Write-Host "   .\deploy-eks-infra.ps1 -Plan" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Deploy infrastructure:" -ForegroundColor Gray
    Write-Host "   .\deploy-aks-infra.ps1" -ForegroundColor Gray
    Write-Host "   .\deploy-eks-infra.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Deploy applications:" -ForegroundColor Gray
    Write-Host "   cd .." -ForegroundColor Gray
    Write-Host "   .\deploy-aks.ps1" -ForegroundColor Gray
    Write-Host "   .\deploy-eks.ps1" -ForegroundColor Gray
}

Write-Success "`nValidation suite complete! 🚀"
exit $exitCode