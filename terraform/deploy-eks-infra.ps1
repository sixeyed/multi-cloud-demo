# deploy-eks-infra.ps1 - Deploy EKS infrastructure using Terraform
# Prerequisites:
# - AWS CLI installed and configured (aws configure)
# - Terraform installed
# - PowerShell 7.0+

param(
    [switch]$Plan,
    [switch]$Destroy,
    [switch]$AutoApprove,
    [string]$Region = "eu-west-2",
    [string]$ClusterName = "multi-cloud-demo-eks",
    [string]$Profile = ""
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
Write-Success "EKS Infrastructure Deployment with Terraform"
Write-Success "=============================================="

# Check prerequisites
Write-Info "Checking prerequisites..."

# Set AWS profile and region if specified
$originalProfile = $env:AWS_PROFILE
$originalRegion = $env:AWS_REGION
if ($Profile) {
    Write-Info "Using AWS profile: $Profile"
    $env:AWS_PROFILE = $Profile
}
$env:AWS_REGION = $Region

# Check AWS CLI
try {
    $awsVersion = aws --version 2>&1
    Write-Success "✓ AWS CLI: $awsVersion"
} catch {
    Write-Error "✗ AWS CLI not found. Please install: https://aws.amazon.com/cli/"
    exit 1
}

# Check AWS credentials
try {
    $awsArgs = @()
    if ($Profile) {
        $awsArgs += @("--profile", $Profile)
    }
    $identity = aws sts get-caller-identity @awsArgs --output json | ConvertFrom-Json
    Write-Success "✓ Logged in to AWS account: $($identity.Account)"
    Write-Info "  User/Role: $($identity.Arn)"
    if ($Profile) {
        Write-Info "  Profile: $Profile"
    }
} catch {
    if ($Profile) {
        Write-Error "✗ AWS credentials not configured for profile '$Profile'. Please run: aws configure --profile $Profile"
    } else {
        Write-Error "✗ AWS credentials not configured. Please run: aws configure"
    }
    exit 1
}

# Check Terraform
try {
    $tfVersion = terraform version -json | ConvertFrom-Json
    Write-Success "✓ Terraform version: $($tfVersion.terraform_version)"
} catch {
    Write-Error "✗ Terraform not found. Please install: https://www.terraform.io/downloads"
    exit 1
}

# Navigate to EKS terraform directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$eksPath = Join-Path $scriptPath "eks"

if (-not (Test-Path $eksPath)) {
    Write-Error "✗ EKS terraform directory not found at: $eksPath"
    exit 1
}

Push-Location $eksPath

try {
    # Initialize Terraform
    Write-Info "`nInitializing Terraform..."
    terraform init
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform init failed"
        exit 1
    }
    Write-Success "✓ Terraform initialized"

    # Create terraform.tfvars if it doesn't exist
    $tfvarsPath = "terraform.tfvars"
    if (-not (Test-Path $tfvarsPath)) {
        Write-Info "Creating terraform.tfvars with custom values..."
        $tfvarsContent = @"
aws_region   = "$Region"
cluster_name = "$ClusterName"
"@
        if ($Profile) {
            $tfvarsContent += "`naws_profile  = `"$Profile`""
        }
        $tfvarsContent | Out-File -FilePath $tfvarsPath -Encoding utf8
        Write-Success "✓ Created terraform.tfvars"
    }

    # Destroy infrastructure if requested
    if ($Destroy) {
        Write-Warning "`nDESTROYING EKS INFRASTRUCTURE..."
        Write-Warning "This will remove all resources including the EKS cluster, VPC, and associated resources."
        
        if ($AutoApprove) {
            terraform destroy -auto-approve
        } else {
            terraform destroy
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "`n✓ EKS infrastructure destroyed successfully"
        } else {
            Write-Error "Terraform destroy failed"
        }
        exit $LASTEXITCODE
    }

    # Always create a plan first
    Write-Info "`nCreating Terraform plan..."
    terraform plan -out=tfplan
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform plan failed"
        exit 1
    }
    
    Write-Success "`n✓ Terraform plan created successfully"
    
    # Plan only if requested
    if ($Plan) {
        Write-Info "Review the plan above and run without -Plan flag to apply"
        exit 0
    }

    # Apply from plan
    Write-Info "`nApplying Terraform plan..."
    Write-Warning "This will create an EKS cluster and associated resources. This process takes 15-20 minutes."
    terraform apply tfplan
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform apply failed"
        exit 1
    }
    
    Write-Success "`n✓ EKS infrastructure deployed successfully!"
    
    # Get outputs
    Write-Info "`nGetting deployment outputs..."
    $outputs = terraform output -json | ConvertFrom-Json
    
    Write-Success "`n=============================================="
    Write-Success "EKS Deployment Summary"
    Write-Success "=============================================="
    Write-Info "Cluster Name: $($outputs.cluster_name.value)"
    Write-Info "Region: $Region"
    Write-Info "Cluster Endpoint: $($outputs.cluster_endpoint.value)"
    Write-Info "VPC ID: $($outputs.vpc_id.value)"
    if ($outputs.ecr_repository_url.value) {
        Write-Info "ECR Repository: $($outputs.ecr_repository_url.value)"
    }
    Write-Info "CloudWatch Logs: $($outputs.cloudwatch_log_group_name.value)"
    Write-Info "S3 Logs Bucket: $($outputs.s3_logs_bucket.value)"
    Write-Success "=============================================="
    
    # Configure kubectl
    Write-Info "`nConfiguring kubectl..."
    if ($Profile) {
        $updateKubeconfigCmd = "aws eks update-kubeconfig --region $Region --name $ClusterName --profile $Profile"
    } else {
        $updateKubeconfigCmd = $outputs.update_kubeconfig_command.value
    }
    Write-Info "Running: $updateKubeconfigCmd"
    Invoke-Expression $updateKubeconfigCmd
    
    # Check what was written to kubeconfig
    Write-Info "`nChecking kubeconfig entry..."
    kubectl config view --minify --raw
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✓ kubectl configured for EKS cluster"
        
        # Test connection
        Write-Info "`nTesting cluster connection..."
        
        # Check current kubectl context
        Write-Info "Current kubectl context:"
        kubectl config current-context
        
        # Test AWS authentication for kubectl
        Write-Info "Testing AWS authentication for kubectl..."
        aws sts get-caller-identity --output table
        
        # Check environment variables
        Write-Info "Current AWS_PROFILE: $($env:AWS_PROFILE)"
        Write-Info "Current AWS_REGION: $($env:AWS_REGION)"
        
        # Try to get token manually to test authentication
        Write-Info "Testing EKS token generation..."
        aws eks get-token --cluster-name $ClusterName --region $Region
        
        Write-Info "Attempting to connect to EKS cluster..."
        kubectl get nodes
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Successfully connected to EKS cluster"
            
            # Check for aws-auth ConfigMap
            Write-Info "`nChecking aws-auth ConfigMap..."
            kubectl get configmap aws-auth -n kube-system
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✓ aws-auth ConfigMap exists"
                kubectl describe configmap aws-auth -n kube-system
            } else {
                Write-Warning "⚠ aws-auth ConfigMap not found - this should be created automatically by the EKS module"
            }
            
            # Check addon status
            Write-Info "`nChecking EKS addons..."
            kubectl get pods -n kube-system | Select-String -Pattern "ebs-csi|coredns"
            
            # Deploy additional addons now that kubectl is configured
            Write-Info "`nDeploying additional Kubernetes addons..."
            terraform apply -auto-approve -var="deploy_addons=true"
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✓ Kubernetes addons deployed successfully"
                
                Write-Info "`nChecking all addons..."
                kubectl get pods -n kube-system | Select-String -Pattern "ebs-csi|coredns|aws-load-balancer-controller"
                
                Write-Info "`nChecking AWS Load Balancer Controller deployment..."
                kubectl get deployment aws-load-balancer-controller -n kube-system
                
                Write-Info "`nChecking AWS Load Balancer Controller pods..."
                kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
                
                Write-Info "`nChecking if LoadBalancer services exist..."
                kubectl get services --all-namespaces --field-selector spec.type=LoadBalancer
                
                Write-Info "`nChecking for any ingress resources..."
                kubectl get ingress --all-namespaces
                
                Write-Info "`nDebugging LoadBalancer issues..."
                
                # Check if any LoadBalancer services exist and debug them
                $lbServices = kubectl get services --all-namespaces --field-selector spec.type=LoadBalancer -o json | ConvertFrom-Json
                if ($lbServices.items.Count -gt 0) {
                    foreach ($service in $lbServices.items) {
                        $serviceName = $service.metadata.name
                        $namespace = $service.metadata.namespace
                        
                        Write-Info "`nDebugging service: $serviceName in namespace: $namespace"
                        
                        # Describe the service
                        kubectl describe service $serviceName -n $namespace
                        
                        # Check endpoints
                        Write-Info "`nChecking endpoints for $serviceName..."
                        kubectl get endpoints $serviceName -n $namespace
                        
                        # Check if pods are ready
                        Write-Info "`nChecking pods with selector..."
                        $selector = $service.spec.selector
                        if ($selector) {
                            $selectorString = ($selector.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ","
                            kubectl get pods -n $namespace -l $selectorString
                        }
                    }
                }
                
                # Check AWS Load Balancer Controller logs
                Write-Info "`nChecking AWS Load Balancer Controller logs..."
                kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=20
                
                Write-Info "`nTo debug further, run:"
                Write-Host "   kubectl describe service <service-name> -n <namespace>" -ForegroundColor Gray
                Write-Host "   kubectl get events --sort-by=.metadata.creationTimestamp" -ForegroundColor Gray
                Write-Host "   nslookup <external-dns-name>" -ForegroundColor Gray
            } else {
                Write-Warning "⚠ Some addons may have failed to deploy"
                Write-Info "`nChecking what failed..."
                terraform plan -var="deploy_addons=true"
            }
        }
    }
    
    # Save outputs to file
    $outputsFile = "eks-outputs.json"
    $outputs | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputsFile -Encoding utf8
    Write-Info "`nOutputs saved to: $outputsFile"
    
    # Next steps
    Write-Info "`nNext Steps:"
    Write-Host "1. Deploy the application:" -ForegroundColor Gray
    Write-Host "   cd ../.." -ForegroundColor Gray
    Write-Host "   .\deploy-eks.ps1 -UpdateDependencies -Wait" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Monitor the cluster:" -ForegroundColor Gray
    Write-Host "   kubectl get nodes" -ForegroundColor Gray
    Write-Host "   kubectl get pods --all-namespaces" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Access CloudWatch Container Insights:" -ForegroundColor Gray
    Write-Host "   https://console.aws.amazon.com/cloudwatch/home?region=$Region#container-insights:infrastructure" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. View EKS Console:" -ForegroundColor Gray
    Write-Host "   https://console.aws.amazon.com/eks/home?region=$Region#/clusters/$ClusterName" -ForegroundColor Gray
    
} finally {
    Pop-Location
    
    # Restore original AWS profile and region
    if ($originalProfile) {
        $env:AWS_PROFILE = $originalProfile
    } else {
        Remove-Item env:AWS_PROFILE -ErrorAction SilentlyContinue
    }
    if ($originalRegion) {
        $env:AWS_REGION = $originalRegion
    } else {
        Remove-Item env:AWS_REGION -ErrorAction SilentlyContinue
    }
}

Write-Success "`nEKS infrastructure deployment complete! 🚀"