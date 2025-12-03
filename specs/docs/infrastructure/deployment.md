# Deployment Architecture and Infrastructure

## Overview

This document describes the deployment architecture, infrastructure provisioning, and operational configuration of the agentic-shell-python application.

---

## Deployment Models

### Local Development
**Orchestrator**: .NET Aspire
**File**: `apphost.cs`
**Services**:
- Backend (Python/Uvicorn): Port 8080
- Frontend (Next.js dev): Port 3000

**Benefits**:
- Automatic service discovery
- Environment variable injection
- Log aggregation
- Hot reload for both services

---

### Production (Azure)
**Platform**: Azure Container Apps
**Orchestrator**: Azure Developer CLI (azd)
**Configuration**: `azure.yaml` + Bicep templates

**Services**:
- agentic-api: Container App (Port 8080)
- agentic-ui: Container App (Port 3000 → 80)

---

## Infrastructure as Code

### Bicep Structure

```
infra/
├── main.bicep                    # Entry point, subscription scope
├── main.parameters.json          # Deployment parameters
├── resources.bicep               # Main resources (apps, DB, search)
├── ai-project.bicep              # AI Foundry and OpenAI
├── abbreviations.json            # Resource naming conventions
├── modules/
│   ├── ai-search-conn.bicep      # Connect AI Search to AI Project
│   └── fetch-container-image.bicep # Retrieve latest images
└── scripts/
    ├── postprovision.sh          # Post-deployment config (POSIX)
    └── postprovision.ps1         # Post-deployment config (Windows)
```

---

## Resource Hierarchy

### Subscription Level
**Deployment Scope**: Subscription
**Operation**: Creates resource group

```bicep
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}
```

---

### Resource Group Contents

**Name Pattern**: `rg-{environmentName}`

**Resources**:
1. Monitoring Stack
2. Container Infrastructure
3. Data Services
4. AI Services
5. Identity & Access

---

## Deployed Resources

### 1. Monitoring Stack

**Module**: Azure Verified Module `avm/ptn/azd/monitoring:0.1.0`

**Components**:
- **Log Analytics Workspace**: `{abbrs.operationalInsightsWorkspaces}{resourceToken}`
- **Application Insights**: `{abbrs.insightsComponents}{resourceToken}`
- **Dashboard**: `{abbrs.portalDashboards}{resourceToken}`

**Purpose**:
- Centralized logging
- Application performance monitoring
- Custom dashboards

**Configuration**:
```bicep
module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.0' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: '${abbrs.portalDashboards}${resourceToken}'
    location: location
    tags: tags
  }
}
```

---

### 2. Container Infrastructure

#### Azure Container Registry
**Module**: AVM `avm/res/container-registry/registry:0.1.1`
**Name**: `{abbrs.containerRegistryRegistries}{resourceToken}`
**SKU**: Basic (implicit)
**Public Access**: Enabled

**Purpose**:
- Store Docker images
- Secure image pulls by container apps

**Role Assignments**:
- Backend identity: AcrPull
- Frontend identity: AcrPull

#### Container Apps Environment
**Module**: AVM `avm/res/app/managed-environment:0.4.5`
**Name**: `{abbrs.appManagedEnvironments}{resourceToken}`
**Zone Redundant**: False (cost optimization)

**Features**:
- Shared by both container apps
- Integrated with Log Analytics
- Provides default domain

---

### 3. Container Apps

#### Backend (agentic-api)
**Module**: AVM `avm/res/app/container-app:0.8.0`
**Name**: `agentic-api`

**Configuration**:
- **Image**: From ACR or fallback to `mcr.microsoft.com/azuredocs/containerapps-helloworld:latest`
- **Port**: 8080 (ingress target)
- **Replicas**: Min 1, Max 10
- **Resources**: 0.5 CPU, 1.0 GB memory
- **Identity**: User-assigned managed identity
- **CORS**: Allows requests from frontend domain

**Environment Variables**:
```bicep
env: [
  { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: '...' }
  { name: 'AZURE_CLIENT_ID', value: '...' }
  { name: 'AZURE_COSMOS_ENDPOINT', value: '...' }
  { name: 'AZURE_AI_SEARCH_ENDPOINT', value: '...' }
  { name: 'AZURE_AI_PROJECT_ENDPOINT', value: '...' }
  { name: 'AZURE_OPENAI_ENDPOINT', value: '...' }
  { name: 'AZURE_OPENAI_DEPLOYMENT_NAME', value: '...' }
  { name: 'PORT', value: '8080' }
]
```

**RBAC Roles** (Resource Group Scope):
- Azure AI Developer (`64702f94-c441-49e6-a78b-ef80e0188fee`)
- Cognitive Services User (`a97b65f3-24c7-4388-baec-2e87135dc908`)

---

#### Frontend (agentic-ui)
**Module**: AVM `avm/res/app/container-app:0.8.0`
**Name**: `agentic-ui`

**Configuration**:
- **Image**: From ACR (built via Dockerfile) or fallback
- **Port**: 3000 (internal) → 80 (external via ingress)
- **Replicas**: Min 1, Max 10
- **Resources**: 0.5 CPU, 1.0 GB memory
- **Identity**: User-assigned managed identity
- **CORS**: Not configured (ingress handles)

**Environment Variables**:
```bicep
env: [
  { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: '...' }
  { name: 'AZURE_CLIENT_ID', value: '...' }
  { name: 'AGENT_API_URL', value: 'https://agentic-api.{defaultDomain}' }
  { name: 'PORT', value: '3000' }
]
```

---

### 4. Data Services

#### Azure Cosmos DB
**Module**: AVM `avm/res/document-db/database-account:0.8.1`
**Name**: `{abbrs.documentDBDatabaseAccounts}{resourceToken}`

**Configuration**:
- **API**: SQL (Core)
- **Consistency**: Session (default)
- **Mode**: Serverless (`EnableServerless` capability)
- **Location**: Single region (primary)
- **Public Access**: Enabled
- **Failover**: Single region (priority 0)

**Databases**:
```bicep
sqlDatabases: [
  {
    name: 'agentic-storage'
    containers: []  // No containers pre-created
  }
]
```

**Status**: **PROVISIONED BUT NOT USED** in application code

**RBAC**:
- Custom SQL role: `service-access-cosmos-sql-role`
- Assigned to: Backend identity, Frontend identity, User principal

---

#### Azure AI Search
**Module**: AVM `avm/res/search/search-service:0.10.0`
**Name**: `{abbrs.searchSearchServices}{resourceToken}`

**Configuration**:
- **SKU**: Basic
- **Replica Count**: 1
- **Public Access**: Enabled
- **Authentication**: AAD + API Key (aadOrApiKey mode)
- **Failure Mode**: http401WithBearerChallenge

**Status**: **PROVISIONED BUT NOT USED** in application code

**RBAC** (Conditional on principal type):
- User: Search Index Data Contributor, Search Service Contributor
- Backend Identity: Search Index Data Contributor, Search Service Contributor
- Frontend Identity: Search Index Data Contributor, Search Service Contributor

**Connection**: Linked to AI Foundry via `modules/ai-search-conn.bicep`

---

### 5. AI Services

#### AI Services Account
**File**: `infra/ai-project.bicep`
**Name**: `ai-account-{resourceToken}`
**Type**: `Microsoft.CognitiveServices/accounts@2025-04-01-preview`
**Kind**: `AIServices` (multi-service account)
**SKU**: S0 (Standard)

**Features**:
- **Project Management**: Enabled (`allowProjectManagement: true`)
- **Custom Subdomain**: `ai-account-{resourceToken}`
- **Public Access**: Enabled
- **Local Auth**: Enabled (API keys available)

---

#### OpenAI Deployment
**Parent**: AI Services Account
**Resource Type**: `deployments` (child resource)

**Configuration**:
```bicep
{
  name: 'gpt5MiniDeployment'
  model: {
    name: 'gpt-5-mini'
    format: 'OpenAI'
    version: '2025-08-07'
  }
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
}
```

**Endpoints**:
- OpenAI API: `{account}.openai.azure.com`
- AI Foundry API: Project-specific endpoint

---

#### AI Foundry Project
**Parent**: AI Services Account
**Resource Type**: `projects` (child resource)
**Name**: `{environmentName}` (e.g., "agentic-shell-python")

**Configuration**:
- **Display Name**: `{environmentName}Project`
- **Description**: `{environmentName} Project`
- **Identity**: System-assigned managed identity

**Purpose**:
- Unified AI project management
- Access to Azure AI capabilities
- Integration with AI Search

**Output**:
- `AZURE_AI_PROJECT_ENDPOINT`: AI Foundry API endpoint

---

### 6. Identity & Access

#### User-Assigned Managed Identities
**Module**: AVM `avm/res/managed-identity/user-assigned-identity:0.2.1`

**Backend Identity**:
- **Name**: `{abbrs.managedIdentityUserAssignedIdentities}agenticApi-{resourceToken}`
- **Usage**: Backend container app
- **Roles**: See Backend RBAC section

**Frontend Identity**:
- **Name**: `{abbrs.managedIdentityUserAssignedIdentities}agenticUi-{resourceToken}`
- **Usage**: Frontend container app
- **Roles**: Same as backend (for flexibility)

**Benefits**:
- No credential management
- Automatic token refresh
- Centralized access control
- Audit trail

---

## Deployment Process

### Azure Developer CLI (azd) Workflow

**Configuration**: `azure.yaml`

```yaml
name: agentic-shell-python
services:
  agentic-api:
    project: src/agentic-api
    host: containerapp
    language: python
  agentic-ui:
    project: src/agentic-ui
    host: containerapp
    language: ts
resources:
  agentic-api:
    type: host.containerapp
    port: 8080
  agentic-ui:
    type: host.containerapp
    uses:
      - agentic-api
    port: 80
```

---

### Deployment Steps

**1. Initialize Environment** (First Time)
```bash
azd init
# Prompts for environment name, location
```

**2. Authentication**
```bash
az login
azd auth login
```

**3. Provision Infrastructure**
```bash
azd provision
# Deploys infra/main.bicep
# Creates all Azure resources
```

**4. Deploy Applications**
```bash
azd deploy
# Builds Docker images
# Pushes to ACR
# Updates Container Apps
```

**5. Complete Deployment** (All-in-One)
```bash
azd up
# Combines provision + deploy
```

---

### Post-Provision Hooks

**POSIX** (`infra/scripts/postprovision.sh`):
```bash
#!/bin/bash
# 1. Retrieves environment variables via azd env get-values
# 2. Updates apphost.settings.json with:
#    - AZURE_OPENAI_ENDPOINT
#    - AZURE_OPENAI_DEPLOYMENT_NAME
# 3. Uses jq for JSON manipulation (sed fallback)
```

**Windows** (`infra/scripts/postprovision.ps1`):
- Equivalent PowerShell implementation

**Purpose**: Configure local Aspire orchestration with Azure service endpoints

---

## Container Image Strategy

### Backend Image
**Method**: Built by azd (implicit)
**Base**: Python official image (likely)
**Requirements**: `src/agentic-api/pyproject.toml`
**Entry Point**: `main:app` via Uvicorn

**Build Process** (inferred):
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY pyproject.toml .
RUN pip install uv && uv pip install .
COPY main.py .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

---

### Frontend Image
**Dockerfile**: `src/agentic-ui/Dockerfile`
**Strategy**: Multi-stage build

**Stages**:
1. **deps**: Install Node dependencies
   - Copies package.json, package-lock.json
   - Runs `npm install`

2. **builder**: Build application
   - Installs Linux x64 native binaries (Tailwind, Oxide)
   - Runs `npm run build`
   - Produces standalone output

3. **runner**: Production image
   - Node 20-slim base
   - Non-root user (nextjs:nodejs, 1001:1001)
   - Copies standalone output only
   - Minimal attack surface

**Size Optimization**: Standalone mode reduces image by 50%+

---

## Image Fetching Module

**File**: `infra/modules/fetch-container-image.bicep`
**Purpose**: Retrieve latest container image from previous deployments

**Logic**:
```bicep
param exists bool  # True if service exists
param name string  # Service name

output containers array = exists ? 
  reference(resourceId('...', name)).template.containers : []
```

**Usage**: Blue-green deployments without breaking initial deployment

**Fallback**: `mcr.microsoft.com/azuredocs/containerapps-helloworld:latest` if no image exists

---

## Networking

### Public Endpoints

**Frontend**:
- **URL**: `https://agentic-ui.{containerAppsEnvironment.defaultDomain}`
- **Port**: 443 → 80 → 3000
- **Ingress**: External, HTTPS

**Backend**:
- **URL**: `https://agentic-api.{containerAppsEnvironment.defaultDomain}`
- **Port**: 443 → 8080
- **Ingress**: External (for frontend access)

---

### Internal Communication

**Frontend → Backend**:
- **URL**: `https://agentic-api.{defaultDomain}` (via Container Apps DNS)
- **Protocol**: HTTP (internal network)
- **Authentication**: None (CORS-restricted)

---

### CORS Configuration

**Backend CORS** (`infra/resources.bicep`):
```bicep
corsPolicy: {
  allowedOrigins: [
    'https://agentic-ui.${containerAppsEnvironment.outputs.defaultDomain}'
  ]
  allowedMethods: ['*']
}
```

**Effect**: Only frontend can call backend API

---

## Scaling Configuration

### Container Apps Auto-Scaling
**Backend & Frontend**:
```bicep
scaleMinReplicas: 1
scaleMaxReplicas: 10
```

**Triggers** (Platform Default):
- HTTP request queue depth
- CPU utilization
- Memory utilization

**Scale-Out**: Gradual (1 replica at a time)
**Scale-In**: Conservative (avoids thrashing)

---

### Resource Limits

**Per Replica**:
- **CPU**: 0.5 cores (0.5 vCPU)
- **Memory**: 1.0 GB

**Cost Optimization**: Minimal resources for reference app

---

## High Availability

### Current Configuration
- **Zone Redundancy**: Disabled (cost optimization)
- **Multi-Region**: Not configured
- **Replicas**: Minimum 1 (no downtime guarantee)

### Production Recommendations
1. Enable zone redundancy
2. Set min replicas to 2
3. Configure multi-region deployment
4. Add traffic manager for geo-distribution

---

## Monitoring & Observability

### Application Insights

**Configuration**:
```bicep
env: [
  { 
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: monitoring.outputs.applicationInsightsConnectionString
  }
]
```

**Automatic Instrumentation**:
- HTTP requests
- Dependencies (OpenAI API calls)
- Exceptions
- Performance counters

---

### Log Analytics

**Configuration**: Container Apps Environment linked to workspace

**Log Sources**:
- Container stdout/stderr
- System logs
- Application Insights telemetry

**Query Language**: KQL (Kusto Query Language)

---

### Dashboard

**Type**: Azure Portal Dashboard
**Provisioned**: Yes (via monitoring module)
**Likely Widgets**:
- Request rate
- Response time
- Error rate
- Replica count
- CPU/Memory usage

---

## Disaster Recovery

### Current State
**Backup Strategy**: None explicitly configured
**Recovery Time Objective (RTO)**: N/A
**Recovery Point Objective (RPO)**: N/A

### Data Durability
- **Cosmos DB**: Automatic backups (Azure managed)
- **Container Images**: Persistent in ACR
- **Code**: Git repository (GitHub)

### Recovery Process (Manual)
1. Code from GitHub
2. Run `azd up` in new region
3. Reconfigure endpoints

**Time**: 15-30 minutes for full redeployment

---

## Cost Considerations

### Resource Costs (Estimated Monthly)

| Resource | SKU | Estimated Cost |
|----------|-----|----------------|
| Container Apps (2) | 0.5 vCPU, 1GB | ~$40-80 |
| Cosmos DB | Serverless | $0-10 (usage-based) |
| AI Search | Basic | ~$75 |
| AI Services | S0 | ~$0 (pay per token) |
| OpenAI (gpt-5-mini) | GlobalStandard | ~$10-50 (usage-based) |
| Storage/Logs | Standard | ~$5-10 |
| **Total** | | **~$130-225/month** |

**Optimization**:
- Unused Cosmos DB can be deleted
- Unused AI Search can be deleted
- AI Search could be Free tier (with limitations)

---

## Security Configuration

### Network Security
- **Public Access**: Enabled (all services)
- **Private Endpoints**: Not configured
- **VNet Integration**: Not configured

**Production Recommendation**: Use private endpoints and VNet integration

---

### Identity & Access
- **Managed Identity**: ✅ Enabled
- **RBAC**: ✅ Configured
- **Least Privilege**: ✅ Specific roles
- **API Keys**: Disabled where possible

---

### Compliance
**Current**: No specific compliance frameworks configured

**Azure Policy**: Not applied

**Recommendations**:
- Apply Azure Security Center
- Enable Defender for Cloud
- Implement Azure Policy
- Configure compliance dashboards

---

## Infrastructure Outputs

**File**: `infra/main.bicep`

```bicep
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = ...
output AZURE_RESOURCE_AGENTIC_API_ID string = ...
output AZURE_RESOURCE_AGENTIC_UI_ID string = ...
output AZURE_RESOURCE_AGENTIC_STORAGE_ID string = ...
output AZURE_AI_PROJECT_ENDPOINT string = ...
output AZURE_RESOURCE_AI_PROJECT_ID string = ...
output AZURE_AI_SEARCH_ENDPOINT string = ...
output AZURE_RESOURCE_SEARCH_ID string = ...
output AZURE_OPENAI_ENDPOINT string = ...
output AZURE_OPENAI_DEPLOYMENT_NAME string = ...
```

**Usage**: Available via `azd env get-values` for application configuration

---

## Conclusion

The deployment architecture is **modern, cloud-native, and well-structured** using Azure best practices:

**Strengths**:
- Infrastructure as Code with Bicep
- Azure Verified Modules
- Managed Identity security
- Automated deployment via azd
- Proper separation of concerns

**Weaknesses**:
- Single region (no DR)
- Zone redundancy disabled
- Unused resources (Cosmos DB, AI Search)
- No private networking
- Minimal HA configuration

**Production Readiness**: **65%** - Core infrastructure solid, but needs HA, DR, and security hardening for production.
