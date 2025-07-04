# deploy-local.ps1 - Deploy Multi-Cloud Demo to local Kubernetes (Docker Desktop)
# Usage: .\deploy-local.ps1 [-Namespace] [-ReleaseName] [-Build] [-Wait] [-WatchLogs] [-UpdateDependencies] [-Restart]

param(
    [string]$Namespace = "messaging-demo",
    [string]$ReleaseName = "demo",
    [switch]$Build,
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
Write-Success "Multi-Cloud Demo - Local Deployment"
Write-Success "=========================================="

# Check prerequisites
Write-Info "Checking prerequisites..."

# Check if kubectl is available
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

# Check if docker is available and running (for building images)
if ($Build) {
    try {
        $null = docker version 2>$null
        Write-Success "✓ docker is available and running"
    } catch {
        Write-Error "✗ docker not found or not running. Please start Docker Desktop."
        exit 1
    }
    
    try {
        $null = docker compose version 2>$null
        Write-Success "✓ docker compose is available"
    } catch {
        Write-Error "✗ docker compose not found. Please install Docker Compose plugin."
        exit 1
    }
}

# Check if Kubernetes context is set
try {
    $currentContext = kubectl config current-context 2>$null
    Write-Success "✓ Kubernetes context: $currentContext"
} catch {
    Write-Error "✗ No Kubernetes context set. Please configure kubectl to connect to your cluster."
    exit 1
}

# Build images if requested
if ($Build) {
    Write-Info "Building Docker images with docker compose..."
    
    docker compose build
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build images with docker compose"
        exit 1
    }
    
    Write-Success "✓ Images built successfully"
}

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
Write-Info "Deploying with Helm..."
$helmArgs = @(
    "upgrade", "--install", $ReleaseName, ".",
    "--namespace", $Namespace,
    "--values", "values-local.yaml",
    "--timeout", "10m"
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

Write-Success "✓ Deployment completed successfully!"

# Restart deployments if requested or if we built new images (forces pods to restart with new images)
if ($Restart -or $Build) {
    if ($Build) {
        Write-Info "Restarting deployments to pick up newly built images..."
    } else {
        Write-Info "Restarting deployments to pick up new images..."
    }
    
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

# Show LoadBalancer IP/Port
$webappService = kubectl get service "$ReleaseName-webapp" -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
if ([string]::IsNullOrEmpty($webappService)) {
    $webappService = "localhost"
}
$webappPort = kubectl get service "$ReleaseName-webapp" -n $Namespace -o jsonpath='{.spec.ports[0].port}'

Write-Success "`n=========================================="
Write-Success "Deployment Summary"
Write-Success "=========================================="
Write-Info "Namespace: $Namespace"
Write-Info "Release: $ReleaseName"
Write-Info "Web App URL: http://${webappService}:${webappPort}"
Write-Success "=========================================="

# Useful commands
Write-Info "`nUseful commands:"
Write-Host "  kubectl get pods -n $Namespace" -ForegroundColor Gray
Write-Host "  kubectl logs -l app.kubernetes.io/component=backgroundworker -n $Namespace -f" -ForegroundColor Gray
Write-Host "  kubectl port-forward svc/$ReleaseName-webapp 8080:80 -n $Namespace" -ForegroundColor Gray
Write-Host "  helm uninstall $ReleaseName -n $Namespace" -ForegroundColor Gray
Write-Host "  .\deploy-local.ps1 -UpdateDependencies  # Check for Redis chart updates" -ForegroundColor Gray
Write-Host "  .\deploy-local.ps1 -Build               # Build images and restart deployments" -ForegroundColor Gray
Write-Host "  .\deploy-local.ps1 -Restart             # Force restart deployments (without building)" -ForegroundColor Gray

# Watch logs if requested
if ($WatchLogs) {
    Write-Info "`nWatching background worker logs... (Press Ctrl+C to stop)"
    Start-Sleep -Seconds 2
    kubectl logs -l "app.kubernetes.io/component=backgroundworker" -n $Namespace -f
}

Write-Success "`nDeployment complete! 🚀"