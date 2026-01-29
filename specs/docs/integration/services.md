# External Services and Dependencies

## Overview

This document catalogs all external services, APIs, and third-party dependencies used by the agentic-shell-python application.

---

## Azure Services

### 1. Azure OpenAI Service

**Purpose**: Core AI/ML service powering the conversational agent
**Status**: ✅ Active (provisioned and connected)

---

#### Configuration

**Deployment**:
- **Account Name**: `{environmentName}-openai-account`
- **Deployment Name**: `gpt5MiniDeployment`
- **Model**: `gpt-5-mini` (preview)
- **Model Version**: `2024-11-20`
- **Capacity**: 100k TPM (Tokens Per Minute)

**Environment Variables**:
- `AZURE_OPENAI_ENDPOINT`: `https://{accountName}.openai.azure.com/`
- `AZURE_OPENAI_DEPLOYMENT_NAME`: `gpt5MiniDeployment`

**Authentication**: Managed Identity (Azure AD)
**RBAC Role**: `Cognitive Services OpenAI User`

---

#### Usage

**SDK**: `azure-ai-inference>=1.0.0b7`
**Client**: `AzureOpenAIChatClient`

**Code Example** (`src/agentic-api/main.py`):
```python
from azure.ai.inference.aio import AzureOpenAIChatClient
from azure.identity.aio import DefaultAzureCredential

chat_client = AzureOpenAIChatClient(
    endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
    credential=DefaultAzureCredential(),
    user_agent="agentic-shell/1.0",
    credential_scopes=["https://cognitiveservices.azure.com/.default"],
)
```

**API Calls**:
- **Endpoint**: `{AZURE_OPENAI_ENDPOINT}/openai/deployments/{DEPLOYMENT_NAME}/chat/completions`
- **Method**: POST
- **Frequency**: Per user message (synchronous, not batched)
- **Typical Latency**: 1-5 seconds

---

#### Rate Limits & Quotas

**Tokens Per Minute (TPM)**: 100,000
**Requests Per Minute (RPM)**: Unlimited (within TPM)
**Concurrent Requests**: No explicit limit

**Throttling Behavior**:
- Returns `429 Too Many Requests` when quota exceeded
- Includes `Retry-After` header
- SDK handles retries automatically

---

#### Cost

**Pricing Model**: Pay-per-token
**Input Tokens**: $0.003 per 1k tokens
**Output Tokens**: $0.015 per 1k tokens

**Estimated Usage**:
- Average input: 200 tokens per request
- Average output: 400 tokens per response
- Cost per request: ~$0.0066

**Monthly Estimate** (1000 requests/day):
- Daily: 1000 × $0.0066 = $6.60
- Monthly: $6.60 × 30 = ~$198

---

#### Monitoring

**Metrics Available**:
- Total token usage (prompt + completion)
- Request latency (E2E)
- Error rate (429, 500, 503)
- Model load

**Azure Monitor Query** (KQL):
```kusto
dependencies
| where type == "HTTP"
| where target contains "openai.azure.com"
| summarize count(), avg(duration) by resultCode
```

---

#### Failure Modes

**429 Too Many Requests**:
- **Cause**: TPM quota exceeded
- **Mitigation**: SDK retries with exponential backoff
- **Recovery**: Wait for quota reset (1-minute window)

**503 Service Unavailable**:
- **Cause**: Azure OpenAI service overloaded
- **Mitigation**: Retry after delay
- **Recovery**: Typically resolves in seconds

**401 Unauthorized**:
- **Cause**: Managed identity token expired
- **Mitigation**: SDK refreshes token automatically
- **Recovery**: Immediate

---

### 2. Azure AI Foundry (AI Project)

**Purpose**: AI development environment for prompt management, evaluation, and experimentation
**Status**: ✅ Provisioned, ⚠️ Not actively used in application code

---

#### Configuration

**Hub**:
- **Name**: `{environmentName}-ai-hub`
- **Location**: Same as resource group
- **Kind**: Hub (parent resource)

**Project**:
- **Name**: `{environmentName}-ai-project`
- **Kind**: Project (child of hub)
- **Friendly Name**: `{environmentName} AI Project`

**Connections** (defined in Bicep):
- Azure OpenAI connection
- Azure AI Search connection

**Environment Variables**:
- `AZURE_AI_PROJECT_ENDPOINT`: AI Foundry project endpoint
- Not actively consumed in `src/agentic-api/main.py`

---

#### Potential Uses

**Prompt Management**:
- Store and version prompt templates
- Test prompts in playground
- Deploy prompts to production

**Evaluation**:
- Upload test datasets
- Run evaluations on model responses
- Track quality metrics (relevance, groundedness, etc.)

**Fine-Tuning**:
- Upload training data
- Fine-tune base models
- Deploy fine-tuned models

**Note**: Currently provisioned but not integrated into application code.

---

#### Cost

**Pricing**: No direct cost (management service)
**Dependencies**: Costs from connected services (OpenAI, Search, Storage)

---

### 3. Azure AI Search

**Purpose**: Semantic search service for RAG (Retrieval-Augmented Generation) patterns
**Status**: ✅ Provisioned, ❌ Not connected in application code

---

#### Configuration

**Service**:
- **Name**: `{environmentName}-search`
- **SKU**: Basic tier
- **Replicas**: 1
- **Partitions**: 1

**Indexes**: None created (service provisioned but empty)

**Environment Variables**:
- `AZURE_AI_SEARCH_ENDPOINT`: `https://{serviceName}.search.windows.net/`
- Not consumed in application code

**Authentication**: Managed Identity
**RBAC Role**: `Search Index Data Contributor`

---

#### Intended Use Case

**RAG Pattern**:
1. Index documents (PDFs, docs, etc.)
2. User asks question
3. Search index for relevant documents
4. Pass documents + question to OpenAI
5. Generate answer grounded in documents

**Example Integration** (not implemented):
```python
from azure.search.documents import SearchClient
from azure.identity import DefaultAzureCredential

search_client = SearchClient(
    endpoint=os.environ["AZURE_AI_SEARCH_ENDPOINT"],
    index_name="documents",
    credential=DefaultAzureCredential()
)

# Search for relevant documents
results = search_client.search(
    search_text=user_query,
    select=["content", "title"],
    top=5
)

# Pass to OpenAI as context
context = "\n".join([r["content"] for r in results])
prompt = f"Context: {context}\n\nQuestion: {user_query}"
```

---

#### Cost

**Pricing** (Basic tier):
- **Fixed Cost**: ~$73/month (no usage-based charges)
- **Storage**: 2 GB included
- **Documents**: 15 million per index

**Status**: Provisioned but unused (~$73/month cost)

---


### 4. Azure Cosmos DB

**Purpose**: Conversation history persistence
**Status**: ✅ Provisioned, ❌ Not connected in application code

**See**: [databases.md](databases.md) for full details

---

#### Configuration

**Account**: `{environmentName}-cosmos-account`
**API**: SQL (Core) API
**Tier**: Serverless
**Database**: `agentic-storage`
**Container**: `conversations` (partition key: `/userId`)

**Environment Variables**:
- `AZURE_COSMOS_ENDPOINT`: `https://{accountName}.documents.azure.com:443/`
- Not consumed in application code

**Authentication**: Managed Identity
**RBAC Role**: `Cosmos DB Built-in Data Contributor`

---

#### Cost

**Pricing**: $0.25 per 1 million RUs + $0.25/GB storage/month
**Current Cost**: ~$0 (no data stored)

**If Implemented** (1000 conversations/day, 10 messages each):
- RU Cost: ~$5-10/month
- Storage: ~$2/month
- **Total**: ~$7-12/month

---

### 5. Azure Container Registry

**Purpose**: Store Docker images for frontend
**Status**: ✅ Active (used in deployment)

---

#### Configuration

**Registry**:
- **Name**: `{environmentName}registry` (max 50 chars, alphanumeric only)
- **SKU**: Basic
- **Admin Enabled**: No (managed identity authentication)

**Images Stored**:
- `agentic-ui:latest` - Next.js frontend container

**Authentication**: Managed Identity (pull access)
**RBAC Role**: `AcrPull` (assigned to Container App identity)

---

#### Usage

**Build & Push** (local):
```bash
az acr build --registry {registryName} --image agentic-ui:latest src/agentic-ui
```

**Build & Push** (azd):
```bash
azd deploy
# Automatically builds and pushes to ACR
```

**Pull** (Container Apps):
- Configured in Container App definition
- Managed identity authenticates to ACR
- Pulls image on deployment/scaling

---

#### Cost

**Pricing** (Basic tier):
- **Fixed**: $5/month (includes 10 GB storage)
- **Storage**: $0.10/GB over 10 GB
- **Network**: Egress charges apply

**Current Usage**: ~1 image (~500 MB)
**Cost**: ~$5/month

---

### 6. Azure Container Apps

**Purpose**: Host backend and frontend containers
**Status**: ✅ Active (running application)

**See**: [deployment.md](../infrastructure/deployment.md) for full details

---

#### Configuration

**Environment**:
- **Name**: `{environmentName}-container-env`
- **Location**: Same as resource group

**Apps**:
1. **agentic-api** (Python/FastAPI)
   - **Image**: Built from source by azd
   - **CPU**: 0.5 cores
   - **Memory**: 1 GB
   - **Scale**: 1-10 replicas
   - **Ingress**: External (HTTPS)

2. **agentic-ui** (Next.js)
   - **Image**: `{registryName}.azurecr.io/agentic-ui:latest`
   - **CPU**: 0.5 cores
   - **Memory**: 1 GB
   - **Scale**: 1-10 replicas
   - **Ingress**: External (HTTPS)

---

#### Cost

**Pricing**:
- **Consumption Plan**: $0.000024/vCPU-second + $0.000003/GB-second
- **Requests**: $0.40 per 1 million requests

**Example** (1 replica, 24/7):
- vCPU: 0.5 × 2,592,000 seconds/month × $0.000024 = $31/month
- Memory: 1 GB × 2,592,000 seconds/month × $0.000003 = $7.78/month
- **Per app**: ~$39/month
- **Total (2 apps)**: ~$78/month

---

### 7. Azure Monitor (Application Insights)

**Purpose**: Observability (logs, metrics, traces)
**Status**: ✅ Active (collecting telemetry)

---

#### Configuration

**Workspace**:
- **Name**: `{environmentName}-workspace`
- **Type**: Log Analytics Workspace
- **Retention**: 30 days (default)

**Application Insights**:
- **Name**: `{environmentName}-appinsights`
- **Connection String**: Auto-injected into Container Apps

**Instrumentation**:
- Backend: OpenTelemetry (configured in `main.py`)
- Frontend: Automatic (Container Apps integration)

---

#### Telemetry Collected

**Logs**:
- Application logs (stdout/stderr)
- HTTP requests (method, URL, status, duration)
- Exceptions and stack traces

**Metrics**:
- Request rate (requests/sec)
- Response time (P50, P95, P99)
- Failure rate (%)
- CPU/memory usage

**Traces**:
- Distributed tracing (if implemented)
- Dependency calls (OpenAI API)

---

#### Cost

**Pricing**:
- **Ingestion**: $2.76/GB (first 5 GB/month free)
- **Retention**: Free for 30 days, $0.12/GB/month thereafter

**Estimated Ingestion** (1000 requests/day):
- Logs: ~50 MB/day
- Metrics: ~10 MB/day
- **Total**: ~1.8 GB/month (within free tier)

---

#### Queries

**Average Response Time**:
```kusto
requests
| where timestamp > ago(1h)
| summarize avg(duration) by bin(timestamp, 5m)
```

**Top Errors**:
```kusto
exceptions
| where timestamp > ago(24h)
| summarize count() by problemId, outerMessage
| top 10 by count_
```

---

### 8. Azure Managed Identity

**Purpose**: Secure authentication to Azure services (no secrets)
**Status**: ✅ Active (used for all service-to-service auth)

---

#### Identities Created

**System-Assigned** (1 per Container App):
- `agentic-api` identity
- `agentic-ui` identity

**User-Assigned** (principal identity):
- Used for azd deployments
- Admin access during provisioning

---

#### RBAC Assignments

**agentic-api Identity**:
- `Cognitive Services OpenAI User` → OpenAI account
- `Cosmos DB Built-in Data Contributor` → Cosmos DB account
- `Search Index Data Contributor` → AI Search service

**agentic-ui Identity**:
- `AcrPull` → Container Registry

**User Principal**:
- `Contributor` → Resource Group
- `Cognitive Services OpenAI Contributor` → OpenAI account
- `Cosmos DB Built-in Data Contributor` → Cosmos DB account
- `Search Index Data Contributor` → AI Search service

---

#### Cost

**Pricing**: Free (no charge for managed identities)

---

## Third-Party Services

### CopilotKit (SaaS)

**Purpose**: UI components and runtime for AI chat interfaces
**Status**: ✅ Active (used in frontend)

---

#### Configuration

**Package**: `@copilotkit/react-ui@^1.10.6`
**Components Used**:
- `CopilotKit` (provider)
- `CopilotSidebar` (chat UI)

**API Endpoint**: Self-hosted (`/api/copilotkit`)
**Backend**: CopilotKit Runtime with HttpAgent adapter

---

#### Cost

**Pricing**: Free (open-source)
**Note**: No external CopilotKit cloud service used; fully self-hosted.

---

## Development Dependencies

### 1. GitHub (Git Hosting)

**Purpose**: Source code version control
**Status**: ✅ Active

**Repository URL**: Not specified in code
**Authentication**: Git credentials or SSH

---

### 2. Azure Developer CLI (azd)

**Purpose**: Deployment orchestration
**Status**: ✅ Active (required for deployments)

**Installation**: https://learn.microsoft.com/azure/developer/azure-developer-cli/
**Commands Used**:
- `azd init` - Initialize project
- `azd provision` - Provision Azure resources
- `azd deploy` - Deploy application
- `azd up` - Provision + deploy

---

### 3. Docker Hub

**Purpose**: Base images for Docker builds
**Status**: ✅ Active (implicit)

**Base Images Used**:
- `node:22-alpine` (Next.js frontend)
- `python:3.12-slim` (dev container base, if used)

**Authentication**: Anonymous (public images)

---

### 4. npm Registry

**Purpose**: JavaScript/TypeScript package manager
**Status**: ✅ Active

**Registry**: https://registry.npmjs.org/
**Packages**: 13 direct dependencies (see [dependencies.md](../technology/dependencies.md))
**Authentication**: Anonymous (public packages)

---

### 5. PyPI (Python Package Index)

**Purpose**: Python package manager
**Status**: ✅ Active

**Registry**: https://pypi.org/
**Packages**: 3 direct dependencies (see [dependencies.md](../technology/dependencies.md))
**Authentication**: Anonymous (public packages)

---

### 6. NuGet Gallery

**Purpose**: .NET package manager (for Aspire)
**Status**: ✅ Active (local dev only)

**Registry**: https://www.nuget.org/
**Packages**: Aspire.Hosting SDK
**Authentication**: Anonymous (public packages)

---

## Service Dependencies Graph

```
┌─────────────────────────────────────────────────────┐
│                    User Browser                     │
└────────────────────┬────────────────────────────────┘
                     │ HTTPS
                     ▼
┌─────────────────────────────────────────────────────┐
│             Azure Container Apps (UI)               │
│                   (Next.js)                         │
└────────────────────┬────────────────────────────────┘
                     │ HTTP (internal)
                     ▼
┌─────────────────────────────────────────────────────┐
│            Azure Container Apps (API)               │
│                  (FastAPI)                          │
└──┬────────────┬──────────────┬──────────────────────┘
   │            │              │
   │            │              │
   │ HTTP       │ HTTP         │ HTTPS
   │            │              │
   ▼            ▼              ▼
┌─────────┐ ┌──────────┐ ┌───────────┐
│ Cosmos  │ │  Azure   │ │  Azure    │
│   DB    │ │  Search  │ │  OpenAI   │
│ (unused)│ │ (unused) │ │ (ACTIVE)  │
└─────────┘ └──────────┘ └───────────┘

                     │
                     │ Telemetry
                     ▼
           ┌──────────────────┐
           │ Application      │
           │ Insights         │
           └──────────────────┘
```

---

## Service Health Monitoring

### Dependencies to Monitor

**Critical Services** (app fails without them):
1. Azure OpenAI (gpt-5-mini deployment)
2. Azure Container Apps (both apps)
3. Azure Container Registry (for deployments)

**Non-Critical Services** (provisioned but unused):
4. Cosmos DB
5. Azure AI Search
6. Azure AI Foundry

---

### Health Checks

**OpenAI Health**:
```python
# Health check endpoint (not implemented)
try:
    response = chat_client.chat(messages=[{"role": "user", "content": "ping"}])
    return {"status": "healthy"}
except Exception as e:
    return {"status": "unhealthy", "error": str(e)}
```

**Container Apps Health**:
- Built-in health probes (TCP)
- Can add custom HTTP health endpoints

---

### Alerting Recommendations

**Alerts to Configure**:
1. **OpenAI 429 Rate Limit**: Alert if >10% of requests throttled
2. **High Latency**: Alert if P95 latency >10 seconds
3. **Error Rate**: Alert if error rate >5%
4. **Container Restart**: Alert if any container restarts
5. **Cost Spike**: Alert if daily spend >2× baseline

---

## Disaster Recovery

### Single Region Deployment

**Current**: All services in one region (e.g., `eastus`)
**Risk**: Regional outage = complete service unavailable

---

### Current Configuration

**Single Region**: All services deployed in one region
**Risk**: Regional outage affects all services
**Recovery**: Manual redeployment required

---


## Compliance & Governance

### Data Residency

**Current**: All data in single region
**GDPR**: EU region deployment recommended for EU users

**Azure Services Data Locations**:
- OpenAI: Model inference in service region
- Cosmos DB: Data stored in configured region
- Application Insights: Logs stored in workspace region
- Container Apps: Execution in environment region

---

### Security

**Secrets Management**:
- ✅ No connection strings in code
- ✅ Managed identities for all Azure services
- ❌ No Azure Key Vault (not required for current setup)

**Network Security**:
- Public endpoints (no private endpoints)
- No network isolation (services accessible from internet)
- ✅ HTTPS for external traffic

---


## Cost Optimization

### Current Monthly Cost Estimate

**Active Services**:
| Service | Estimated Cost |
|---------|----------------|
| Azure OpenAI (gpt-5-mini) | $150-200 |
| Container Apps (2 apps) | $80 |
| Container Registry | $5 |
| Application Insights | $0 (free tier) |
| **Total Active** | **$235-285** |

**Unused Services**:
| Service | Wasted Cost |
|---------|-------------|
| Azure AI Search (Basic) | $73 |
| Cosmos DB (serverless) | $1 |
| **Total Wasted** | **$74** |

**Grand Total**: **$309-359/month**

---

---




## Summary

### Service Dependencies

**Active Services**:
- Azure OpenAI (core AI service)
- Azure Container Apps (hosting)
- Azure Container Registry (deployments)
- Application Insights (monitoring)
- Managed Identity (security)

**Provisioned but Unused**:
- Cosmos DB (conversation persistence, not implemented)
- Azure AI Search (RAG, not implemented)
- Azure AI Foundry (evaluation, not integrated)

### Current State

**Infrastructure**:
- Core AI functionality operational
- Managed identity authentication
- Monitoring and logging enabled
- Single region deployment
- Public endpoints
- Unused resources provisioned
