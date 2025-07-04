# deploy-aks.ps1 - Deploy Multi-Cloud Demo to Azure AKS
# Usage: .\deploy-aks.ps1 [-Namespace] [-ReleaseName] [-Wait] [-WatchLogs] [-UpdateDependencies]

param(
    [string]$Namespace = "messaging-demo",
    [string]$ReleaseName = "demo",
    [switch]$Wait,
    [switch]$WatchLogs,
    [switch]$UpdateDependencies
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
Write-Success "Multi-Cloud Demo - Azure AKS Deployment"  
Write-Success "=========================================="

# Check prerequisites
Write-Info "Checking prerequisites..."

# Check if kubectl is available and configured for AKS
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

# Check if connected to AKS cluster
try {
    $currentContext = kubectl config current-context 2>$null
    if ($currentContext -like "*aks*" -or $currentContext -like "*azure*") {
        Write-Success "✓ Connected to AKS context: $currentContext"
    } else {
        Write-Warning "⚠ Current context '$currentContext' doesn't appear to be AKS. Continuing anyway..."
    }
} catch {
    Write-Error "✗ No Kubernetes context set. Please configure kubectl to connect to your AKS cluster."
    Write-Info "  Example: az aks get-credentials --resource-group myResourceGroup --name myAKSCluster"
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

# Deploy with Helm
Write-Info "Deploying to AKS with Helm..."
$helmArgs = @(
    "upgrade", "--install", $ReleaseName, ".",
    "--namespace", $Namespace,
    "--values", "values-aks.yaml",
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

Write-Success "✓ AKS deployment completed successfully!"

# Show deployment status
Write-Info "Checking deployment status..."
kubectl get pods -n $Namespace

# Get service information
Write-Info "`nService information:"
kubectl get services -n $Namespace

# Get LoadBalancer information
$webappService = kubectl get service "$ReleaseName-multi-cloud-demo-webapp" -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
$webappPort = kubectl get service "$ReleaseName-multi-cloud-demo-webapp" -n $Namespace -o jsonpath='{.spec.ports[0].port}'

Write-Success "`n=========================================="
Write-Success "AKS Deployment Summary"
Write-Success "=========================================="
Write-Info "Namespace: $Namespace"
Write-Info "Release: $ReleaseName"
Write-Info "Resource Group: $(az account show --query 'name' -o tsv 2>$null)"
if (![string]::IsNullOrEmpty($webappService)) {
    Write-Info "Web App URL: http://${webappService}:${webappPort}"
} else {
    Write-Warning "LoadBalancer IP not yet available"
}
Write-Success "=========================================="

# Useful commands
Write-Info "`nUseful AKS commands:"
Write-Host "  kubectl get pods -n $Namespace" -ForegroundColor Gray
Write-Host "  kubectl logs -l app.kubernetes.io/component=backgroundworker -n $Namespace -f" -ForegroundColor Gray
Write-Host "  kubectl get storageclass" -ForegroundColor Gray
Write-Host "  kubectl get pvc -n $Namespace" -ForegroundColor Gray
Write-Host "  az aks show --resource-group myRG --name myCluster" -ForegroundColor Gray
Write-Host "  helm uninstall $ReleaseName -n $Namespace" -ForegroundColor Gray

# Watch logs if requested
if ($WatchLogs) {
    Write-Info "`nWatching background worker logs... (Press Ctrl+C to stop)"
    Start-Sleep -Seconds 2
    kubectl logs -l "app.kubernetes.io/component=backgroundworker" -n $Namespace -f
}

Write-Success "`nAKS deployment complete! 🚀"