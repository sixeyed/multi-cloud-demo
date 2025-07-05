# install-tools-linux.ps1 - Install all required tools on Linux (Ubuntu/Debian)
# Prerequisites: PowerShell 7+ (install with: wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb)

param(
    [switch]$OptionalTools,
    [switch]$Verify,
    [switch]$SkipPowerShell
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
Write-Success "Multi-Cloud Demo - Linux Tool Installation"
Write-Success "=============================================="

# Check if running as root
if ($env:USER -eq "root") {
    Write-Warning "Running as root. Some installations may behave differently."
}

# Update package list
Write-Info "`nUpdating package list..."
sudo apt update
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to update package list"
    exit 1
}

# Install PowerShell 7 if not skipped
if (-not $SkipPowerShell) {
    Write-Info "`nChecking PowerShell installation..."
    try {
        $psVersion = pwsh --version
        Write-Success "✓ PowerShell is already installed: $psVersion"
    } catch {
        Write-Info "Installing PowerShell 7..."
        
        # Install Microsoft package repository
        wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
        sudo dpkg -i packages-microsoft-prod.deb
        sudo apt update
        
        # Install PowerShell
        sudo apt install -y powershell
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ PowerShell 7 installed successfully"
        } else {
            Write-Error "✗ PowerShell 7 installation failed"
            exit 1
        }
        
        # Clean up
        rm -f packages-microsoft-prod.deb
    }
}

# Install core dependencies
Write-Info "`nInstalling core dependencies..."
sudo apt install -y curl wget unzip apt-transport-https ca-certificates gnupg lsb-release

# Install Terraform
Write-Info "`nInstalling Terraform..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt update
sudo apt install -y terraform

if ($LASTEXITCODE -eq 0) {
    Write-Success "✓ Terraform installed"
} else {
    Write-Warning "⚠ Terraform installation may have failed"
}

# Install kubectl
Write-Info "`nInstalling kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

if (kubectl version --client 2>$null) {
    Write-Success "✓ kubectl installed"
} else {
    Write-Warning "⚠ kubectl installation may have failed"
}

# Install Helm
Write-Info "`nInstalling Helm..."
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt update
sudo apt install -y helm

if ($LASTEXITCODE -eq 0) {
    Write-Success "✓ Helm installed"
} else {
    Write-Warning "⚠ Helm installation may have failed"
}

# Install Azure CLI
Write-Info "`nInstalling Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

if ($LASTEXITCODE -eq 0) {
    Write-Success "✓ Azure CLI installed"
} else {
    Write-Warning "⚠ Azure CLI installation may have failed"
}

# Install AWS CLI
Write-Info "`nInstalling AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Clean up
rm -f awscliv2.zip
rm -rf aws/

if (aws --version 2>$null) {
    Write-Success "✓ AWS CLI installed"
} else {
    Write-Warning "⚠ AWS CLI installation may have failed"
}

# Install optional tools
if ($OptionalTools) {
    Write-Info "`nInstalling optional tools..."
    
    # TFLint
    Write-Info "Installing TFLint..."
    curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
    
    # jq
    Write-Info "Installing jq..."
    sudo apt install -y jq
    
    # yq
    Write-Info "Installing yq..."
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
    
    # Git (if not already installed)
    Write-Info "Installing Git..."
    sudo apt install -y git
    
    # Docker
    Write-Info "Installing Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    
    # Add user to docker group
    sudo usermod -aG docker $env:USER
    Write-Info "Added $env:USER to docker group. You may need to log out and back in for this to take effect."
    
    Write-Success "✓ Optional tools installed"
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
Write-Host "1. If you installed Docker, log out and back in to use it without sudo" -ForegroundColor Gray
Write-Host "2. Configure cloud authentication:" -ForegroundColor Gray
Write-Host "   pwsh ../cloud/setup-azure.ps1" -ForegroundColor Gray
Write-Host "   pwsh ../cloud/setup-aws.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Deploy infrastructure:" -ForegroundColor Gray
Write-Host "   cd ../../terraform" -ForegroundColor Gray
Write-Host "   pwsh ./deploy-aks-infra.ps1 -Plan" -ForegroundColor Gray

Write-Success "`nLinux tool installation complete! 🚀"