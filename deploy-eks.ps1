# deploy-eks.ps1 - Deploy Multi-Cloud Demo to Amazon EKS
# Usage: .\deploy-eks.ps1 [-Namespace] [-ReleaseName] [-Wait] [-WatchLogs] [-UpdateDependencies] [-Restart]

param(
    [string]$Namespace = "messaging-demo",
    [string]$ReleaseName = "demo",
    [switch]$Wait,
    [switch]$WatchLogs,
    [switch]$UpdateDependencies,
    [switch]$Restart
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
Write-Success "=========================================="
Write-Success "Multi-Cloud Demo - Amazon EKS Deployment"
Write-Success "=========================================="

# Check prerequisites
Write-Info "Checking prerequisites..."

# Check if kubectl is available and configured for EKS
try {
    $null = kubectl version --client 2>$null
    Write-Success "✓ kubectl is available"
} catch {
    Write-Error "✗ kubectl not found. Please install kubectl and ensure it's in your PATH."
    exit 1
}

# Check if helm is available
try {
    $null = helm version 2>$null
    Write-Success "✓ helm is available"
} catch {
    Write-Error "✗ helm not found. Please install helm and ensure it's in your PATH."
    exit 1
}

# Check if connected to EKS cluster
try {
    $currentContext = kubectl config current-context 2>$null
    if ($currentContext -like "*eks*" -or $currentContext -like "*amazon*") {
        Write-Success "✓ Connected to EKS context: $currentContext"
    } else {
        Write-Warning "⚠ Current context '$currentContext' doesn't appear to be EKS. Continuing anyway..."
    }
} catch {
    Write-Error "✗ No Kubernetes context set. Please configure kubectl to connect to your EKS cluster."
    Write-Info "  Example: aws eks update-kubeconfig --region us-west-2 --name my-cluster"
    exit 1
}

# Note: StorageClass will be created automatically by Helm chart

# Create namespace if it doesn't exist
Write-Info "Creating namespace '$Namespace'..."
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
if ($LASTEXITCODE -eq 0) {
    Write-Success "✓ Namespace '$Namespace' ready"
} else {
    Write-Error "Failed to create namespace"
    exit 1
}

# Update Helm dependencies if requested
if ($UpdateDependencies) {
    Write-Info "Updating Helm dependencies..."
    Push-Location "helm/multi-cloud-demo"
    helm dependency update
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to update Helm dependencies"
        Pop-Location
        exit 1
    }
} else {
    Write-Info "Skipping dependency update (use -UpdateDependencies to check for Redis chart updates)"
    Push-Location "helm/multi-cloud-demo"
}

# Detect CPU architecture from Docker
Write-Info "Detecting CPU architecture..."
$dockerArch = "amd64"  # default
try {
    $dockerInfo = docker system info --format "{{.Architecture}}" 2>$null
    if ($dockerInfo -eq "aarch64" -or $dockerInfo -like "*arm64*") {
        $dockerArch = "arm64"
        Write-Info "Detected ARM64 architecture (Apple Silicon)"
    } else {
        Write-Info "Detected AMD64 architecture"
    }
} catch {
    Write-Warning "Could not detect Docker architecture, defaulting to AMD64"
}

# Info about ARM64 deployment
if ($dockerArch -eq "arm64") {
    Write-Info "ARM64 architecture detected - will deploy to ARM64 nodes (Apple Silicon compatible)"
    Write-Info "If deployment fails with 'exec format error', ARM64 nodes may not be available."
    Write-Info "To ensure ARM64 nodes are enabled:"
    Write-Host "  terraform apply -var='enable_arm64_nodes=true'" -ForegroundColor Gray
}

# Deploy with Helm
Write-Info "Deploying to EKS with Helm (targeting $dockerArch nodes)..."
$helmArgs = @(
    "upgrade", "--install", $ReleaseName, ".",
    "--namespace", $Namespace,
    "--values", "values-eks.yaml",
    "--set", "architecture.nodeArch=$dockerArch",
    "--timeout", "15m"
)

if ($Wait) {
    $helmArgs += "--wait"
}

helm @helmArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "Helm deployment failed"
    Pop-Location
    exit 1
}

Pop-Location

Write-Success "✓ EKS deployment completed successfully!"

# Restart deployments if requested (forces pods to restart with new images)
if ($Restart) {
    Write-Info "Restarting deployments to pick up new images..."
    
    # Find and restart webapp deployment
    $webappDeployment = kubectl get deployments -n $Namespace -l "app.kubernetes.io/component=webapp" -o name 2>$null
    if ($webappDeployment) {
        kubectl rollout restart $webappDeployment -n $Namespace
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ WebApp deployment restarted"
        } else {
            Write-Warning "⚠ Failed to restart WebApp deployment"
        }
    } else {
        Write-Warning "⚠ WebApp deployment not found"
    }
    
    # Find and restart backgroundworker deployment
    $workerDeployment = kubectl get deployments -n $Namespace -l "app.kubernetes.io/component=backgroundworker" -o name 2>$null
    if ($workerDeployment) {
        kubectl rollout restart $workerDeployment -n $Namespace
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ BackgroundWorker deployment restarted"
        } else {
            Write-Warning "⚠ Failed to restart BackgroundWorker deployment"
        }
    } else {
        Write-Warning "⚠ BackgroundWorker deployment not found"
    }
    
    # Wait for rollouts to complete
    Write-Info "Waiting for rollouts to complete..."
    if ($webappDeployment) {
        kubectl rollout status $webappDeployment -n $Namespace --timeout=300s
    }
    if ($workerDeployment) {
        kubectl rollout status $workerDeployment -n $Namespace --timeout=300s
    }
    Write-Success "✓ All deployments restarted successfully"
}

# Show deployment status
Write-Info "Checking deployment status..."
kubectl get pods -n $Namespace

# Get service information
Write-Info "`nService information:"
kubectl get services -n $Namespace

# Get LoadBalancer information
$webappService = kubectl get service "$ReleaseName-multi-cloud-demo-webapp" -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
if ([string]::IsNullOrEmpty($webappService)) {
    $webappService = kubectl get service "$ReleaseName-multi-cloud-demo-webapp" -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
}
$webappPort = kubectl get service "$ReleaseName-multi-cloud-demo-webapp" -n $Namespace -o jsonpath='{.spec.ports[0].port}'

Write-Success "`n=========================================="
Write-Success "EKS Deployment Summary"
Write-Success "=========================================="
Write-Info "Namespace: $Namespace"
Write-Info "Release: $ReleaseName"
Write-Info "Region: $(aws configure get region 2>$null)"
if (![string]::IsNullOrEmpty($webappService)) {
    Write-Info "Web App URL: http://${webappService}:${webappPort}"
} else {
    Write-Warning "LoadBalancer IP/hostname not yet available"
}
Write-Success "=========================================="

# Useful commands
Write-Info "`nUseful EKS commands:"
Write-Host "  kubectl get pods -n $Namespace" -ForegroundColor Gray
Write-Host "  kubectl logs -l app.kubernetes.io/component=backgroundworker -n $Namespace -f" -ForegroundColor Gray
Write-Host "  kubectl get storageclass" -ForegroundColor Gray
Write-Host "  kubectl get pvc -n $Namespace" -ForegroundColor Gray
Write-Host "  aws eks describe-cluster --name myCluster" -ForegroundColor Gray
Write-Host "  helm uninstall $ReleaseName -n $Namespace" -ForegroundColor Gray
Write-Host "  .\deploy-eks.ps1 -UpdateDependencies  # Check for Redis chart updates" -ForegroundColor Gray
Write-Host "  .\deploy-eks.ps1 -Restart             # Force restart deployments with new images" -ForegroundColor Gray

# Watch logs if requested
if ($WatchLogs) {
    Write-Info "`nWatching background worker logs... (Press Ctrl+C to stop)"
    Start-Sleep -Seconds 2
    kubectl logs -l "app.kubernetes.io/component=backgroundworker" -n $Namespace -f
}

Write-Success "`nEKS deployment complete! 🚀"