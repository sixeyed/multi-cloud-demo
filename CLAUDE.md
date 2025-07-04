# CLAUDE.md - AI Assistant Memory File

## Project Overview
This is a multi-cloud Kubernetes demo application showcasing how containerized .NET applications can be deployed consistently across different cloud providers. The application demonstrates modern microservices patterns, message queuing, database persistence, and Kubernetes deployment best practices.

## Architecture

### Components
- **WebApp**: ASP.NET Core web application with Razor Pages
  - Form for message submission
  - Messages page displaying processed data from SQL Server
  - Modern gradient UI design with 3rem font sizes
  - Antiforgery tokens disabled for demo simplicity
  
- **BackgroundWorker**: .NET background service
  - Processes messages from Redis queue
  - Saves processed messages to SQL Server
  - Multiple replicas (3) demonstrating horizontal scaling
  
- **MultiCloudDemo.Shared**: Shared class library
  - Common models (Message entity)
  - Database context (MessageDbContext)
  - Database initialization utility (DatabaseInitializer)
  
- **Infrastructure**:
  - Redis: Message queue for reliable delivery
  - SQL Server: Persistent storage for messages

### Message Flow
1. User submits message via WebApp form
2. Message is pushed to Redis queue
3. BackgroundWorker picks up message from Redis
4. Message is processed and saved to SQL Server
5. Messages page displays stored messages from database

## Development Environment

### Local Development
- **Docker Compose**: `docker-compose.yml` provides complete local environment
- **Image Tags**: Uses `:2507` tag for consistent local builds
- **Build Context**: Updated to `./src` to include shared library
- **Services**: webapp, backgroundworker, redis, sqlserver with health checks

### Build System
- **Multi-stage Dockerfiles**: Separate build and runtime stages
- **Shared Library Support**: Dockerfiles copy both project and shared library
- **Dependency Management**: Project references to shared library

## Kubernetes Deployment

### Helm Chart Structure
```
helm/multi-cloud-demo/
├── Chart.yaml                 # Chart metadata with Redis dependency
├── values.yaml               # Default values
├── values-local.yaml         # Docker Desktop settings
├── values-staging.yaml       # Staging environment
├── values-production.yaml    # Production environment
├── config/
│   ├── webapp-appsettings.json
│   └── backgroundworker-appsettings.json
└── templates/
    ├── webapp-*.yaml
    ├── backgroundworker-*.yaml
    ├── sqlserver-*.yaml
    └── serviceaccount.yaml
```

### Configuration Management
- **ConfigMaps**: JSON configuration files with Helm templating
- **Secrets**: SQL Server passwords
- **Environment-specific values**: Different resource limits and configurations
- **Checksum annotations**: Auto-rollout when ConfigMaps change

### Kubernetes Features Demonstrated
- **Deployments**: With health probes (startup, readiness, liveness)
- **Services**: ClusterIP and LoadBalancer types
- **PersistentVolumeClaims**: For SQL Server data persistence
- **Init Containers**: Dependency management (wait for SQL Server DNS)
- **Resource Management**: CPU/memory limits and requests
- **Health Checks**: Proper probe configuration
- **Scaling**: Multiple replicas with anti-affinity

## Deployment Automation

### PowerShell Script (`deploy-local.ps1`)
- **Prerequisites Check**: kubectl, helm, docker availability
- **Namespace Management**: Auto-creation
- **Dependency Updates**: Optional Bitnami Redis chart updates
- **Build Integration**: Optional Docker Compose build
- **Restart Functionality**: Label-based deployment restarts
- **Status Monitoring**: Pod and service status display
- **Log Watching**: Background worker log tailing

### Script Features
- **Label-based Restarts**: Uses `app.kubernetes.io/component` labels
- **Automatic Restart**: Triggers when `-Build` flag is used
- **Error Handling**: Graceful handling of missing deployments
- **Colored Output**: Success, info, warning, error messages
- **Flexible Options**: Build, Wait, WatchLogs, UpdateDependencies, Restart

## Database Management

### Entity Framework Setup
- **Code-First Approach**: Message entity with EF Core annotations
- **Database Initialization**: Shared `DatabaseInitializer` class
- **Race Condition Handling**: Either service can initialize database
- **Connection Management**: Separate connection strings for each service

### SQL Server Configuration
- **Resource Allocation**: 2GB RAM, 1 CPU (learned from OOMKill issues)
- **Persistent Storage**: PVC for data retention
- **Health Probes**: Startup probe with sqlcmd, TCP socket for readiness/liveness
- **Init Containers**: DNS-based dependency checking

## Lessons Learned

### Resource Management
- **SQL Server Memory**: Initial 1GB limit caused OOMKills (Exit Code 137)
- **Solution**: Increased to 2GB RAM, 1 CPU for stability
- **Monitoring**: Exit codes reveal resource starvation issues

### Probe Configuration
- **Startup Probe**: Use sqlcmd for actual SQL Server readiness
- **Liveness Probe**: TCP socket check sufficient when resources adequate
- **Readiness Probe**: TCP socket for traffic routing decisions

### Docker Build Optimization
- **Shared Libraries**: Requires careful Dockerfile COPY order
- **Build Context**: Must include all referenced projects
- **Multi-stage Builds**: Separate restore, build, publish stages

### Helm Best Practices
- **Values Files**: Environment-specific configurations
- **ConfigMap Checksums**: Force rollouts on configuration changes
- **Template Functions**: Use `include` and `tpl` for complex configurations
- **Dependency Management**: Bitnami Redis chart integration

### Development Workflow
- **Image Tag Strategy**: Fixed tags (`:2507`) for local development
- **Restart Automation**: Label-based pod restarts for new images
- **Build Integration**: Automatic restart when building locally

## Configuration Details

### Connection Strings
- **Redis**: `{release-name}-redis-master:6379,connectRetry=5,connectTimeout=10000,abortConnect=false`
- **SQL Server**: `Server={fullname}-sqlserver,1433;Database=MultiCloudDemo;User Id=sa;Password={password};TrustServerCertificate=true;`

### Service Names
- **WebApp**: `{release-name}-{chart-name}-webapp`
- **BackgroundWorker**: `{release-name}-{chart-name}-backgroundworker`
- **SQL Server**: `{release-name}-{chart-name}-sqlserver`
- **Redis**: `{release-name}-redis-master` (from Bitnami chart)

### Resource Recommendations
- **WebApp**: 200m CPU, 256Mi RAM (2 replicas)
- **BackgroundWorker**: 100m CPU, 128Mi RAM (3 replicas)
- **SQL Server**: 1000m CPU, 2Gi RAM (1 replica, ReadWriteOnce)
- **Redis**: Default Bitnami settings

## Error Handling

### Database Connection Failures
- **WebApp**: Graceful degradation, warning logs, continues startup
- **BackgroundWorker**: Fails startup if database unavailable
- **Messages Page**: Shows error message instead of crashing

### Common Issues and Solutions
1. **ImagePullBackOff**: Use `imagePullPolicy: IfNotPresent` for local images
2. **SQL Server Restarts**: Increase memory limits (2GB minimum)
3. **Redis Connection Failures**: Check service names, add retry parameters
4. **ConfigMap Updates**: Use checksums to trigger pod rollouts

## UI/UX Considerations
- **Modern Design**: Gradient backgrounds, large fonts (3rem headers)
- **Responsive**: Mobile-friendly layouts
- **User Feedback**: Clear success/error states
- **Navigation**: Simple two-page structure
- **Accessibility**: Proper semantic HTML and form labels

## Security Considerations
- **Antiforgery Disabled**: Appropriate for demo, not production
- **SQL Server Passwords**: Stored in Kubernetes secrets
- **TrustServerCertificate**: Required for containerized SQL Server
- **Non-root Containers**: Security contexts for production

## Future Enhancements
- **Observability**: Add logging, metrics, tracing
- **CI/CD**: GitHub Actions or Azure DevOps pipelines
- **Multi-cloud**: AWS, Azure, GCP deployment examples
- **Service Mesh**: Istio integration
- **Monitoring**: Prometheus, Grafana dashboards

## File Structure
```
multi-cloud-demo/
├── src/                      # Source code
│   ├── WebApp/              # Web application
│   ├── BackgroundWorker/    # Background service
│   ├── MultiCloudDemo.Shared/ # Shared library
│   └── MultiCloudDemo.sln   # Solution file
├── helm/                    # Kubernetes deployment
│   └── multi-cloud-demo/   # Helm chart
├── docker-compose.yml      # Local development
├── deploy-local.ps1        # Deployment automation
├── .gitignore             # Git ignore patterns
└── CLAUDE.md              # This file
```

## Quick Start Commands
```bash
# Local development with Docker Compose
docker compose up -d

# Kubernetes deployment
./deploy-local.ps1 -Build -WatchLogs

# Build and restart deployments
./deploy-local.ps1 -Build

# Just restart (after external build)
./deploy-local.ps1 -Restart
```

---
*This file is maintained by Claude Code to preserve project knowledge and decisions.*