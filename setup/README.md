# Setup Scripts for Multi-Cloud Demo

This directory contains automated setup scripts to install all required tools and configure cloud authentication for the multi-cloud demo project.

## Quick Start

### 1. Install Tools

Choose your operating system:

**macOS:**
```powershell
pwsh ./tools/install-tools-macos.ps1
```

**Windows:**
```powershell
pwsh ./tools/install-tools-windows.ps1
```

**Linux (Ubuntu/Debian):**
```powershell
pwsh ./tools/install-tools-linux.ps1
```

### 2. Configure Cloud Authentication

**Azure:**
```powershell
pwsh ./cloud/setup-azure.ps1
```

**AWS:**
```powershell
pwsh ./cloud/setup-aws.ps1
```

### 3. Deploy Infrastructure

```powershell
cd ../terraform
pwsh ./deploy-aks-infra.ps1 -Plan    # For Azure AKS
pwsh ./deploy-eks-infra.ps1 -Plan    # For AWS EKS
```

## Tool Installation Scripts

### macOS (`install-tools-macos.ps1`)

Installs tools using Homebrew:
- Terraform
- kubectl
- Helm
- Azure CLI
- AWS CLI
- Optional: TFLint, pre-commit, jq, yq, Docker, Git

**Usage:**
```powershell
# Basic installation
pwsh ./tools/install-tools-macos.ps1

# Skip Homebrew installation (if already installed)
pwsh ./tools/install-tools-macos.ps1 -SkipHomebrew

# Include optional tools
pwsh ./tools/install-tools-macos.ps1 -OptionalTools

# Verify installations only
pwsh ./tools/install-tools-macos.ps1 -Verify
```

### Windows (`install-tools-windows.ps1`)

Supports multiple package managers:
- Chocolatey (default)
- Scoop
- Winget

**Usage:**
```powershell
# Using Chocolatey (default)
pwsh ./tools/install-tools-windows.ps1

# Using Scoop
pwsh ./tools/install-tools-windows.ps1 -PackageManager Scoop

# Using Winget
pwsh ./tools/install-tools-windows.ps1 -PackageManager Winget

# Include optional tools
pwsh ./tools/install-tools-windows.ps1 -OptionalTools
```

### Linux (`install-tools-linux.ps1`)

Installs tools using apt package manager and direct downloads:

**Usage:**
```powershell
# Basic installation
pwsh ./tools/install-tools-linux.ps1

# Include optional tools (Docker, TFLint, etc.)
pwsh ./tools/install-tools-linux.ps1 -OptionalTools

# Skip PowerShell installation
pwsh ./tools/install-tools-linux.ps1 -SkipPowerShell
```

## Cloud Configuration Scripts

### Azure (`setup-azure.ps1`)

Configures Azure authentication and registers required resource providers:

**Features:**
- Azure CLI login with device code support
- Subscription selection
- Resource provider registration
- Permission verification
- Optional service principal creation

**Usage:**
```powershell
# Basic setup
pwsh ./cloud/setup-azure.ps1

# Use device code login (for headless environments)
pwsh ./cloud/setup-azure.ps1 -DeviceCode

# Set specific subscription
pwsh ./cloud/setup-azure.ps1 -SubscriptionName "My Subscription"
pwsh ./cloud/setup-azure.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"

# Register providers only
pwsh ./cloud/setup-azure.ps1 -RegisterProviders

# Verify setup only
pwsh ./cloud/setup-azure.ps1 -Verify
```

**Registered Azure Providers:**
- Microsoft.ContainerService (AKS)
- Microsoft.OperationsManagement (Log Analytics)
- Microsoft.OperationalInsights (Log Analytics Workspaces)
- Microsoft.Insights (Application Insights)
- Microsoft.Storage (Storage Accounts)
- Microsoft.Network (Virtual Networks)
- Microsoft.ContainerRegistry (Azure Container Registry)
- Microsoft.Authorization (Role Assignments)
- Microsoft.Compute (Virtual Machines)
- Microsoft.KeyVault (Key Vault)

### AWS (`setup-aws.ps1`)

Configures AWS authentication and verifies permissions:

**Features:**
- Multiple authentication methods
- Region configuration
- Permission verification
- Optional IAM user creation for Terraform

**Usage:**
```powershell
# Basic setup
pwsh ./cloud/setup-aws.ps1

# Force credential configuration
pwsh ./cloud/setup-aws.ps1 -ConfigureCredentials

# Set specific region
pwsh ./cloud/setup-aws.ps1 -Region "eu-west-1"

# Create IAM user for Terraform automation
pwsh ./cloud/setup-aws.ps1 -CreateUser

# Use specific profile
pwsh ./cloud/setup-aws.ps1 -Profile "my-profile"
```

**Authentication Methods:**
1. **Interactive configuration** (`aws configure`)
2. **Environment variables** (AWS_ACCESS_KEY_ID, etc.)
3. **IAM roles** (for EC2 instances)
4. **AWS SSO** (for enterprise environments)

## Prerequisites

### PowerShell 7+

All scripts require PowerShell 7 or later. Install it first:

**macOS:**
```bash
brew install --cask powershell
```

**Windows:**
```powershell
winget install Microsoft.PowerShell
```

**Linux:**
```bash
wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt update && sudo apt install -y powershell
```

### Internet Connection

All scripts require internet access to download packages and tools.

### Administrator/Sudo Access

- **Windows**: Run PowerShell as Administrator for package manager installation
- **macOS/Linux**: Sudo access required for system package installation

## Troubleshooting

### Common Issues

**PowerShell Execution Policy (Windows):**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Package Manager Not Found:**
- The scripts will automatically install package managers if they're missing
- For manual installation, follow the prompts in the error messages

**Permission Errors:**
- Ensure you have appropriate permissions for your cloud subscriptions
- For Azure: Contributor role on subscription
- For AWS: Policies listed in the setup script

**Tool Not Found After Installation:**
- Restart your terminal/PowerShell session
- Check if the tool is in your PATH
- For Windows, log out and back in to refresh environment variables

### Verification

Each script includes verification steps to ensure tools are properly installed and configured. Run with `-Verify` flag to check current state:

```powershell
# Check tool installations
pwsh ./tools/install-tools-macos.ps1 -Verify

# Check cloud configurations
pwsh ./cloud/setup-azure.ps1 -Verify
pwsh ./cloud/setup-aws.ps1 -Verify
```

### Manual Installation

If automated scripts fail, refer to the main [terraform/README.md](../terraform/README.md) for manual installation instructions.

## Environment Variables

After running cloud setup scripts, you may want to set these environment variables for Terraform automation:

**Azure (Service Principal):**
```bash
export ARM_CLIENT_ID="your-app-id"
export ARM_CLIENT_SECRET="your-password"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
```

**AWS (IAM User):**
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="your-region"
```

## Next Steps

After completing the setup:

1. **Validate your infrastructure configurations:**
   ```powershell
   cd ../terraform
   pwsh ./validate-terraform.ps1
   ```

2. **Deploy infrastructure:**
   ```powershell
   pwsh ./deploy-aks-infra.ps1 -Plan  # Review plan first
   pwsh ./deploy-aks-infra.ps1        # Deploy AKS
   
   pwsh ./deploy-eks-infra.ps1 -Plan  # Review plan first
   pwsh ./deploy-eks-infra.ps1        # Deploy EKS
   ```

3. **Deploy the application:**
   ```powershell
   cd ..
   pwsh ./deploy-aks.ps1    # Deploy to AKS
   pwsh ./deploy-eks.ps1    # Deploy to EKS
   ```

## Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review the detailed installation instructions in [terraform/README.md](../terraform/README.md)
3. Ensure you have the required permissions for your cloud subscriptions
4. Verify your internet connection and package manager configurations

---

🤖 **Built with Claude Code** - Automated setup for seamless multi-cloud development