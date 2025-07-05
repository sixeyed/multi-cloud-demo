# install-tools-windows.ps1 - Install all required tools on Windows
# Prerequisites: PowerShell 7+ (install with: winget install Microsoft.PowerShell)

param(
    [ValidateSet("Chocolatey", "Scoop", "Winget", "Manual")]
    [string]$PackageManager = "Chocolatey",
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
Write-Success "Multi-Cloud Demo - Windows Tool Installation"
Write-Success "=============================================="
Write-Info "Using package manager: $PackageManager"

# Check execution policy
if ((Get-ExecutionPolicy) -eq "Restricted") {
    Write-Warning "PowerShell execution policy is Restricted. Setting to RemoteSigned for current user..."
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
}

# Install package manager if needed
switch ($PackageManager) {
    "Chocolatey" {
        Write-Info "`nChecking Chocolatey installation..."
        try {
            $chocoVersion = choco --version 2>$null
            Write-Success "✓ Chocolatey is already installed: $chocoVersion"
        } catch {
            Write-Info "Installing Chocolatey..."
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✓ Chocolatey installed successfully"
                # Refresh environment variables
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            } else {
                Write-Error "✗ Chocolatey installation failed"
                exit 1
            }
        }
    }
    
    "Scoop" {
        Write-Info "`nChecking Scoop installation..."
        try {
            $scoopVersion = scoop --version 2>$null
            Write-Success "✓ Scoop is already installed: $scoopVersion"
        } catch {
            Write-Info "Installing Scoop..."
            Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Invoke-RestMethod get.scoop.sh | Invoke-Expression
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✓ Scoop installed successfully"
                # Add buckets
                scoop bucket add main
                scoop bucket add extras
            } else {
                Write-Error "✗ Scoop installation failed"
                exit 1
            }
        }
    }
    
    "Winget" {
        Write-Info "`nChecking Winget installation..."
        try {
            $wingetVersion = winget --version 2>$null
            Write-Success "✓ Winget is already available: $wingetVersion"
        } catch {
            Write-Error "✗ Winget not available. Please install from Microsoft Store or use another package manager."
            exit 1
        }
    }
}

# Core tools installation
Write-Info "`nInstalling core tools..."

switch ($PackageManager) {
    "Chocolatey" {
        $coreTools = @(
            "terraform",
            "kubernetes-cli",
            "kubernetes-helm", 
            "azure-cli",
            "awscli"
        )
        
        foreach ($tool in $coreTools) {
            Write-Info "Installing $tool..."
            choco install $tool -y
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✓ $tool installed"
            } else {
                Write-Warning "⚠ $tool installation may have failed or was already installed"
            }
        }
    }
    
    "Scoop" {
        $coreTools = @(
            "terraform",
            "kubectl",
            "helm",
            "azure-cli",
            "aws"
        )
        
        foreach ($tool in $coreTools) {
            Write-Info "Installing $tool..."
            scoop install $tool
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✓ $tool installed"
            } else {
                Write-Warning "⚠ $tool installation may have failed or was already installed"
            }
        }
    }
    
    "Winget" {
        $coreTools = @(
            @{ name = "terraform"; id = "Hashicorp.Terraform" },
            @{ name = "kubectl"; id = "Kubernetes.kubectl" },
            @{ name = "helm"; id = "Helm.Helm" },
            @{ name = "azure-cli"; id = "Microsoft.AzureCLI" },
            @{ name = "aws-cli"; id = "Amazon.AWSCLI" }
        )
        
        foreach ($tool in $coreTools) {
            Write-Info "Installing $($tool.name)..."
            winget install --id $tool.id --silent --accept-package-agreements --accept-source-agreements
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✓ $($tool.name) installed"
            } else {
                Write-Warning "⚠ $($tool.name) installation may have failed or was already installed"
            }
        }
    }
}

# Optional tools
if ($OptionalTools) {
    Write-Info "`nInstalling optional tools..."
    
    switch ($PackageManager) {
        "Chocolatey" {
            $optionalTools = @("tflint", "git", "jq", "docker-desktop")
            foreach ($tool in $optionalTools) {
                Write-Info "Installing $tool..."
                choco install $tool -y
            }
        }
        
        "Scoop" {
            $optionalTools = @("tflint", "git", "jq", "docker")
            foreach ($tool in $optionalTools) {
                Write-Info "Installing $tool..."
                scoop install $tool
            }
        }
        
        "Winget" {
            $optionalTools = @(
                @{ name = "git"; id = "Git.Git" },
                @{ name = "docker"; id = "Docker.DockerDesktop" }
            )
            foreach ($tool in $optionalTools) {
                Write-Info "Installing $($tool.name)..."
                winget install --id $tool.id --silent
            }
        }
    }
}

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

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
        Write-Info "Try restarting your terminal/PowerShell session"
    }
}

# Next steps
Write-Info "`nNext Steps:"
Write-Host "1. Restart your terminal/PowerShell session to refresh PATH" -ForegroundColor Gray
Write-Host "2. Configure cloud authentication:" -ForegroundColor Gray
Write-Host "   pwsh ../cloud/setup-azure.ps1" -ForegroundColor Gray
Write-Host "   pwsh ../cloud/setup-aws.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Deploy infrastructure:" -ForegroundColor Gray
Write-Host "   cd ../../terraform" -ForegroundColor Gray
Write-Host "   pwsh ./deploy-aks-infra.ps1 -Plan" -ForegroundColor Gray

Write-Success "`nWindows tool installation complete! 🚀"