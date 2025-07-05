# install-tools-macos.ps1 - Install all required tools on macOS
# Prerequisites: PowerShell 7+ (install with: brew install --cask powershell)

param(
    [switch]$SkipHomebrew,
    [switch]$OptionalTools,
    [switch]$Verify
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
Write-Success "Multi-Cloud Demo - macOS Tool Installation"
Write-Success "=============================================="

# Check if Homebrew is installed
if (-not $SkipHomebrew) {
    Write-Info "`nChecking Homebrew installation..."
    
    try {
        $brewVersion = brew --version 2>$null
        Write-Success "✓ Homebrew is already installed"
    } catch {
        Write-Info "Installing Homebrew..."
        $installScript = '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        Invoke-Expression $installScript
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Homebrew installed successfully"
        } else {
            Write-Error "✗ Homebrew installation failed"
            exit 1
        }
    }
}

# Core tools installation
Write-Info "`nInstalling core tools..."

$coreTools = @(
    @{ name = "terraform"; formula = "hashicorp/tap/terraform"; tap = "hashicorp/tap" },
    @{ name = "kubectl"; formula = "kubectl" },
    @{ name = "helm"; formula = "helm" },
    @{ name = "azure-cli"; formula = "azure-cli"; alias = "az" },
    @{ name = "awscli"; formula = "awscli"; alias = "aws" }
)

foreach ($tool in $coreTools) {
    Write-Info "Installing $($tool.name)..."
    
    # Add tap if specified
    if ($tool.tap) {
        brew tap $tool.tap 2>$null
    }
    
    # Install the tool
    brew install $tool.formula
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✓ $($tool.name) installed"
    } else {
        Write-Warning "⚠ $($tool.name) installation may have failed or was already installed"
    }
}

# Optional tools
if ($OptionalTools) {
    Write-Info "`nInstalling optional tools..."
    
    $optionalTools = @(
        "tflint",
        "pre-commit",
        "jq",
        "yq",
        "docker",
        "git"
    )
    
    foreach ($tool in $optionalTools) {
        Write-Info "Installing $tool..."
        brew install $tool
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ $tool installed"
        } else {
            Write-Warning "⚠ $tool installation may have failed or was already installed"
        }
    }
}

# Verification
if ($Verify -or -not $PSBoundParameters.ContainsKey('Verify')) {
    Write-Info "`nVerifying installations..."
    
    $verifications = @(
        @{ name = "PowerShell"; command = { $PSVersionTable.PSVersion.ToString() }; expectedPattern = "^7\." },
        @{ name = "Terraform"; command = { terraform --version }; expectedPattern = "Terraform v" },
        @{ name = "kubectl"; command = { kubectl version --client --output=yaml 2>$null }; expectedPattern = "gitVersion" },
        @{ name = "Helm"; command = { helm version --short }; expectedPattern = "v3\." },
        @{ name = "Azure CLI"; command = { az --version }; expectedPattern = "azure-cli" },
        @{ name = "AWS CLI"; command = { aws --version }; expectedPattern = "aws-cli" }
    )
    
    $allSuccess = $true
    
    foreach ($verification in $verifications) {
        try {
            $output = & $verification.command
            if ($output -match $verification.expectedPattern) {
                Write-Success "✓ $($verification.name): Working"
            } else {
                Write-Warning "⚠ $($verification.name): Unexpected output"
                $allSuccess = $false
            }
        } catch {
            Write-Error "✗ $($verification.name): Not found or not working"
            $allSuccess = $false
        }
    }
    
    if ($allSuccess) {
        Write-Success "`n🎉 All tools installed and verified successfully!"
    } else {
        Write-Warning "`n⚠ Some tools may need manual verification or installation"
    }
}

# Next steps
Write-Info "`nNext Steps:"
Write-Host "1. Configure cloud authentication:" -ForegroundColor Gray
Write-Host "   pwsh ../cloud/setup-azure.ps1" -ForegroundColor Gray
Write-Host "   pwsh ../cloud/setup-aws.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Optional: Set up enhanced tooling:" -ForegroundColor Gray
Write-Host "   pwsh ./setup-optional.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Deploy infrastructure:" -ForegroundColor Gray
Write-Host "   cd ../../terraform" -ForegroundColor Gray
Write-Host "   pwsh ./deploy-aks-infra.ps1 -Plan" -ForegroundColor Gray

Write-Success "`nmacOS tool installation complete! 🚀"