# setup-aws.ps1 - Configure AWS authentication and permissions
# Prerequisites: AWS CLI installed

param(
    [string]$Region = "eu-west-2",
    [string]$Profile = "default",
    [switch]$ConfigureCredentials,
    [switch]$Verify,
    [switch]$CreateUser
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
Write-Success "Multi-Cloud Demo - AWS Setup"
Write-Success "=============================================="

# Check AWS CLI installation
Write-Info "`nChecking AWS CLI installation..."
try {
    $awsVersion = aws --version
    Write-Success "✓ AWS CLI: $awsVersion"
} catch {
    Write-Error "✗ AWS CLI not found. Please install it first:"
    Write-Info "macOS: brew install awscli"
    Write-Info "Windows: winget install Amazon.AWSCLI"
    Write-Info "Linux: curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip' && unzip awscliv2.zip && sudo ./aws/install"
    exit 1
}

# Check current AWS configuration
Write-Info "`nChecking AWS authentication..."
try {
    $awsArgs = @()
    if ($Profile -ne "default") {
        $awsArgs += @("--profile", $Profile)
    }
    $identity = aws sts get-caller-identity @awsArgs --output json | ConvertFrom-Json
    Write-Success "✓ Already authenticated to AWS"
    Write-Info "  Account: $($identity.Account)"
    Write-Info "  User/Role: $($identity.Arn)"
    if ($Profile -ne "default") {
        Write-Info "  Profile: $Profile"
        Write-Info "  Region: $(aws configure get region --profile $Profile)"
    } else {
        Write-Info "  Region: $(aws configure get region)"
    }
} catch {
    Write-Warning "⚠ AWS credentials not configured or invalid"
    $ConfigureCredentials = $true
}

# Configure credentials if needed
if ($ConfigureCredentials) {
    Write-Info "`nConfiguring AWS credentials..."
    Write-Info "You have several options:"
    Write-Host "1. Interactive configuration (aws configure)" -ForegroundColor Gray
    Write-Host "2. Environment variables" -ForegroundColor Gray
    Write-Host "3. IAM roles (for EC2/Lambda)" -ForegroundColor Gray
    Write-Host "4. AWS SSO" -ForegroundColor Gray
    
    $choice = Read-Host "`nChoose configuration method (1-4)"
    
    switch ($choice) {
        "1" {
            Write-Info "Starting interactive AWS configuration..."
            Write-Host "You'll need:" -ForegroundColor Yellow
            Write-Host "- Access Key ID" -ForegroundColor Yellow
            Write-Host "- Secret Access Key" -ForegroundColor Yellow
            Write-Host "- Default region (e.g., us-east-1)" -ForegroundColor Yellow
            Write-Host "- Default output format (json recommended)" -ForegroundColor Yellow
            
            aws configure --profile $Profile
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✓ AWS credentials configured successfully"
            } else {
                Write-Error "✗ AWS credential configuration failed"
                exit 1
            }
        }
        
        "2" {
            Write-Info "Using environment variables..."
            Write-Host "Set these environment variables:" -ForegroundColor Yellow
            Write-Host "export AWS_ACCESS_KEY_ID='your-access-key'" -ForegroundColor Gray
            Write-Host "export AWS_SECRET_ACCESS_KEY='your-secret-key'" -ForegroundColor Gray
            Write-Host "export AWS_DEFAULT_REGION='$Region'" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Windows PowerShell:" -ForegroundColor Yellow
            Write-Host "`$env:AWS_ACCESS_KEY_ID='your-access-key'" -ForegroundColor Gray
            Write-Host "`$env:AWS_SECRET_ACCESS_KEY='your-secret-key'" -ForegroundColor Gray
            Write-Host "`$env:AWS_DEFAULT_REGION='$Region'" -ForegroundColor Gray
            
            $continue = Read-Host "`nPress Enter after setting environment variables"
        }
        
        "3" {
            Write-Info "Using IAM roles..."
            Write-Host "If you're running on an EC2 instance, attach an IAM role with these policies:" -ForegroundColor Yellow
            Write-Host "- AmazonEKSClusterPolicy" -ForegroundColor Gray
            Write-Host "- AmazonEKSWorkerNodePolicy" -ForegroundColor Gray
            Write-Host "- AmazonEKS_CNI_Policy" -ForegroundColor Gray
            Write-Host "- AmazonEC2ContainerRegistryReadOnly" -ForegroundColor Gray
            Write-Host "- EC2FullAccess" -ForegroundColor Gray
            Write-Host "- IAMFullAccess" -ForegroundColor Gray
            
            $continue = Read-Host "`nPress Enter after attaching the IAM role"
        }
        
        "4" {
            Write-Info "Setting up AWS SSO..."
            aws configure sso --profile $Profile
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✓ AWS SSO configured successfully"
            } else {
                Write-Error "✗ AWS SSO configuration failed"
                exit 1
            }
        }
        
        default {
            Write-Error "Invalid choice. Please run the script again."
            exit 1
        }
    }
}

# Set default region
if ($Region -ne "us-east-1") {
    Write-Info "`nSetting default region to $Region..."
    aws configure set region $Region --profile $Profile
}

# Verification
if ($Verify -or -not $PSBoundParameters.ContainsKey('Verify')) {
    Write-Info "`nVerifying AWS setup..."
    
    # Test basic AWS CLI functionality
    try {
        $awsArgs = @()
        if ($Profile -ne "default") {
            $awsArgs += @("--profile", $Profile)
        }
        $identity = aws sts get-caller-identity @awsArgs --output json | ConvertFrom-Json
        Write-Success "✓ AWS CLI authentication working"
        Write-Info "  Account: $($identity.Account)"
        Write-Info "  User/Role: $($identity.Arn.Split('/')[-1])"
        
        if ($Profile -ne "default") {
            $currentRegion = aws configure get region --profile $Profile
            Write-Info "  Profile: $Profile"
        } else {
            $currentRegion = aws configure get region
        }
        if (-not $currentRegion) { $currentRegion = "us-east-1" }
        Write-Info "  Region: $currentRegion"
        
        # Test basic permissions
        Write-Info "Testing basic AWS permissions..."
        
        # Test EC2 describe (minimal permission)
        aws ec2 describe-regions @awsArgs --region $currentRegion --output table 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Basic AWS permissions verified"
        } else {
            Write-Warning "⚠ Limited AWS permissions - some operations may fail"
        }
        
        # Test EKS permissions
        aws eks list-clusters @awsArgs --region $currentRegion --output json 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ EKS permissions verified"
        } else {
            Write-Warning "⚠ EKS permissions may be limited"
        }
        
    } catch {
        Write-Error "✗ AWS CLI verification failed"
        Write-Info "Please check your credentials and try again"
        exit 1
    }
    
    # Check required permissions
    Write-Info "`nChecking required AWS permissions..."
    $requiredServices = @(
        @{ service = "ec2"; action = "describe-regions" },
        @{ service = "eks"; action = "list-clusters" },
        @{ service = "iam"; action = "list-roles" },
        @{ service = "ecr"; action = "describe-repositories" }
    )
    
    foreach ($check in $requiredServices) {
        try {
            aws $check.service $check.action @awsArgs --region $currentRegion --output json 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✓ $($check.service.ToUpper()): Access verified"
            } else {
                Write-Warning "⚠ $($check.service.ToUpper()): Limited access"
            }
        } catch {
            Write-Warning "⚠ $($check.service.ToUpper()): Could not verify access"
        }
    }
}

# Create IAM user for Terraform (optional)
if ($CreateUser) {
    Write-Info "`nCreating IAM user for Terraform automation..."
    
    $userName = "terraform-multi-cloud-demo"
    
    try {
        # Create IAM user
        aws iam create-user --user-name $userName --output json | Out-Null
        Write-Success "✓ IAM user '$userName' created"
        
        # Attach required policies
        $policies = @(
            "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
            "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy", 
            "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
            "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
            "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
            "arn:aws:iam::aws:policy/IAMFullAccess"
        )
        
        foreach ($policy in $policies) {
            aws iam attach-user-policy --user-name $userName --policy-arn $policy
            Write-Info "✓ Attached policy: $($policy.Split('/')[-1])"
        }
        
        # Create access key
        $accessKey = aws iam create-access-key --user-name $userName --output json | ConvertFrom-Json
        
        Write-Success "✓ Access key created for Terraform user"
        Write-Info "`nAccess Key Details (save these securely):"
        Write-Host "  Access Key ID: $($accessKey.AccessKey.AccessKeyId)" -ForegroundColor Yellow
        Write-Host "  Secret Access Key: $($accessKey.AccessKey.SecretAccessKey)" -ForegroundColor Yellow
        
        Write-Info "`nTo use this user with Terraform, set these environment variables:"
        Write-Host "export AWS_ACCESS_KEY_ID='$($accessKey.AccessKey.AccessKeyId)'" -ForegroundColor Gray
        Write-Host "export AWS_SECRET_ACCESS_KEY='$($accessKey.AccessKey.SecretAccessKey)'" -ForegroundColor Gray
        Write-Host "export AWS_DEFAULT_REGION='$currentRegion'" -ForegroundColor Gray
        
    } catch {
        Write-Warning "⚠ IAM user creation failed. You may need administrator permissions or can use your existing credentials."
    }
}

# Next steps
Write-Success "`n🎉 AWS setup complete!"
Write-Info "`nNext Steps:"
Write-Host "1. Deploy EKS infrastructure:" -ForegroundColor Gray
Write-Host "   cd ../../terraform" -ForegroundColor Gray
if ($Profile -ne "default") {
    Write-Host "   pwsh ./deploy-eks-infra.ps1 -Plan -Profile $Profile" -ForegroundColor Gray
} else {
    Write-Host "   pwsh ./deploy-eks-infra.ps1 -Plan" -ForegroundColor Gray
}
Write-Host ""
Write-Host "2. Or set up Azure for multi-cloud deployment:" -ForegroundColor Gray
Write-Host "   pwsh ./setup-azure.ps1" -ForegroundColor Gray

Write-Info "`nUseful AWS commands:"
Write-Host "  aws configure list           # Show current configuration" -ForegroundColor Gray
Write-Host "  aws sts get-caller-identity  # Show current user/role" -ForegroundColor Gray
Write-Host "  aws eks list-clusters        # List EKS clusters" -ForegroundColor Gray
Write-Host "  aws ec2 describe-regions     # List available regions" -ForegroundColor Gray
Write-Host "  aws configure set region <region>  # Change default region" -ForegroundColor Gray