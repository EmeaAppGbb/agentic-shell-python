# Component Architecture and Relationships

## Overview

This document details the internal structure of each major component in the agentic-shell-python application and maps the relationships and dependencies between them.

---

## Component Inventory

### 1. Frontend Component (agentic-ui)
**Type**: Next.js 16 App Router Application
**Location**: `src/agentic-ui/`
**Deployment**: Azure Container App
**Port**: 3000 (internal) → 80 (external)

### 2. Backend Component (agentic-api)
**Type**: Python FastAPI Application
**Location**: `src/agentic-api/`
**Deployment**: Azure Container App
**Port**: 8080

### 3. App Host Component (Aspire Orchestrator)
**Type**: .NET Aspire Application Host
**Location**: `apphost.cs`
**Purpose**: Local development orchestration

### 4. Infrastructure Component
**Type**: Azure Bicep IaC
**Location**: `infra/`
**Purpose**: Cloud resource provisioning

---

## Frontend Component Breakdown

### File Structure
```
src/agentic-ui/
├── app/
│   ├── layout.tsx          # Root layout with CopilotKit provider
│   ├── page.tsx            # Main page with CopilotSidebar
│   ├── globals.css         # Global styles
│   └── api/
│       └── copilotkit/
│           └── route.ts    # Backend integration endpoint
├── public/                 # Static assets
├── Dockerfile              # Container definition
├── package.json            # Dependencies
├── next.config.ts          # Next.js configuration
├── tsconfig.json           # TypeScript configuration
└── eslint.config.mjs       # Linting rules
```

### Component Hierarchy

```
RootLayout (layout.tsx)
│
├── CopilotKit (provider)
│   │
│   └── Page (page.tsx)
│       │
│       └── CopilotSidebar
│           │
│           ├── Chat Interface
│           ├── Message History
│           └── Input Field
│
└── Main Content
    │
    ├── Hero Section
    │   ├── Title: "Agentic Shell"
    │   └── Description
    │
    └── Feature Cards (3)
        ├── Fast Responses
        ├── Contextual Understanding
        └── Secure & Private
```

### Sub-Components

#### 1. RootLayout (`app/layout.tsx`)
**Responsibility**: Application wrapper and provider setup

**Props**:
- `children`: React.ReactNode

**Structure**:
```tsx
<html lang="en">
  <body>
    <CopilotKit runtimeUrl="/api/copilotkit" agent="my_agent">
      {children}
    </CopilotKit>
  </body>
</html>
```

**Dependencies**:
- `@copilotkit/react-core` (CopilotKit component)
- `globals.css` (styles)

---

#### 2. Page Component (`app/page.tsx`)
**Responsibility**: Main application UI

**Key Elements**:
- `CopilotSidebar`: AI chat interface
  - Props:
    - `defaultOpen={true}`
    - `labels` object with title, initial message, placeholder
    - `instructions` for the AI assistant
- Hero section with gradient background
- Three feature cards with icons and descriptions

**Dependencies**:
- `@copilotkit/react-ui` (CopilotSidebar)

---

#### 3. API Route (`app/api/copilotkit/route.ts`)
**Responsibility**: Bridge between frontend and backend agent

**Structure**:
```typescript
// 1. Service Adapter
const serviceAdapter = new ExperimentalEmptyAdapter();

// 2. Runtime Configuration
const runtime = new CopilotRuntime({
  agents: {
    my_agent: new HttpAgent({ 
      url: process.env.AGENT_API_URL 
    }),
  },
});

// 3. Next.js API Handler
export const POST = async (req: NextRequest) => {
  const { handleRequest } = copilotRuntimeNextJSAppRouterEndpoint({
    runtime,
    serviceAdapter,
    endpoint: "/api/copilotkit",
  });
  return handleRequest(req);
};
```

**Dependencies**:
- `@copilotkit/runtime` (CopilotRuntime, ExperimentalEmptyAdapter)
- `@ag-ui/client` (HttpAgent)
- `next/server` (NextRequest)

**Environment Variables**:
- `AGENT_API_URL`: Backend API URL (default: `http://localhost:5149`)

---

## Backend Component Breakdown

### File Structure
```
src/agentic-api/
├── main.py                 # FastAPI app and agent setup
└── pyproject.toml          # Python dependencies
```

### Component Layers

```
HTTP Request
    ↓
FastAPI Application (main.py)
    ↓
Agent Framework Endpoint (/)
    ↓
ChatAgent ("AGUIAssistant")
    ↓
AzureOpenAIChatClient
    ↓
Azure OpenAI Service
```

### Sub-Components

#### 1. FastAPI Application
**Responsibility**: HTTP server and lifecycle management

**Code Structure**:
```python
@contextlib.asynccontextmanager
async def lifespan(app):
    telemetry.configure_opentelemetry()
    yield

app = fastapi.FastAPI(lifespan=lifespan)
```

**Features**:
- Async lifespan context for startup/shutdown
- OpenTelemetry configuration on startup
- Single endpoint registration (via agent framework)

---

#### 2. ChatAgent
**Responsibility**: AI agent logic and behavior

**Configuration**:
```python
agent = ChatAgent(
    name="AGUIAssistant",
    instructions="You are a helpful assistant.",
    chat_client=chat_client,
)
```

**Properties**:
- **name**: Identifier for the agent
- **instructions**: System prompt/instructions
- **chat_client**: Connection to AI model

**Capabilities** (from Agent Framework):
- Message handling
- Context management
- Tool/function calling (if configured)
- Streaming responses (if enabled)

---

#### 3. AzureOpenAIChatClient
**Responsibility**: Azure OpenAI API integration

**Configuration**:
```python
chat_client = AzureOpenAIChatClient(
    credential=AzureCliCredential(),
    endpoint=endpoint,  # from AZURE_OPENAI_ENDPOINT
    deployment_name=deployment_name,  # from AZURE_OPENAI_DEPLOYMENT_NAME
)
```

**Authentication**: 
- Local: `AzureCliCredential()` (az login)
- Production: Managed Identity (via AZURE_CLIENT_ID env var)

**Model**: gpt-5-mini (specified in deployment)

---

#### 4. Agent Framework Endpoint
**Responsibility**: FastAPI endpoint registration

**Code**:
```python
add_agent_framework_fastapi_endpoint(app, agent, "/")
```

**Behavior**:
- Registers root path "/" as agent endpoint
- Handles AG-UI protocol messages
- Marshals requests/responses between HTTP and agent

---

## Orchestration Component Breakdown (Aspire)

### File: `apphost.cs`

**Purpose**: Local development service orchestration

### Structure
```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Parameters
var openAiEndpoint = builder.AddParameter("openAiEndpoint");
var openAiDeployment = builder.AddParameter("openAiDeployment");

// Backend Service
var api = builder.AddUvicornApp("agentic-api", "./src/agentic-api", "main:app")
    .WithUv()
    .WithEnvironment("AZURE_OPENAI_ENDPOINT", openAiEndpoint)
    .WithEnvironment("AZURE_OPENAI_DEPLOYMENT_NAME", openAiDeployment)
    .WithExternalHttpEndpoints();

// Frontend Service
builder.AddJavaScriptApp("agentic-ui", "./src/agentic-ui")
    .WithRunScript("dev")
    .WithNpm(installCommand: "ci")
    .WithEnvironment("AGENT_API_URL", api.GetEndpoint("http"))
    .WithReference(api)
    .WaitFor(api)
    .WithHttpEndpoint(env: "PORT")
    .WithExternalHttpEndpoints()
    .PublishAsDockerFile();

builder.Build().Run();
```

### Orchestration Features
1. **Parameter Management**: OpenAI endpoint and deployment from settings
2. **Service Discovery**: `api.GetEndpoint("http")` for inter-service communication
3. **Dependency Management**: `WaitFor(api)` ensures backend starts first
4. **Environment Injection**: Automatic environment variable propagation
5. **Container Publishing**: Frontend has Docker build for deployment

### Configuration Files
- **apphost.settings.json**: Runtime parameters (OpenAI config)
- **apphost.settings.template.json**: Template for initial setup
- **apphost.run.json**: Aspire runtime configuration

---

## Infrastructure Component Breakdown

### Main Infrastructure (`infra/main.bicep`)

**Structure**:
```bicep
Subscription Scope
    ↓
Resource Group (rg-{environmentName})
    ↓
[Modules]
    ├── resources.bicep (app resources)
    ├── ai-project.bicep (AI services)
    └── modules/
        ├── ai-search-conn.bicep (search connection)
        └── fetch-container-image.bicep (image retrieval)
```

### Resource Hierarchy

```
Resource Group
│
├── Monitoring Stack (AVM module)
│   ├── Log Analytics Workspace
│   ├── Application Insights
│   └── Dashboard
│
├── Container Infrastructure
│   ├── Container Registry
│   ├── Container Apps Environment
│   ├── Container App: agentic-api
│   └── Container App: agentic-ui
│
├── Data Layer
│   ├── Cosmos DB Account
│   │   └── Database: agentic-storage
│   └── AI Search Service
│
├── AI Services
│   ├── AI Services Account
│   │   ├── Deployment: gpt-5-mini
│   │   └── Project: {environmentName}
│   └── AI Search Connection
│
└── Identity & Access
    ├── Managed Identity: agenticApi
    ├── Managed Identity: agenticUi
    └── RBAC Role Assignments
```

---

## Component Dependencies Map

### Frontend Dependencies
```
agentic-ui (Next.js)
    ├── Depends On: agentic-api (HTTP)
    ├── Uses: Container Apps Environment
    ├── Logs To: Application Insights
    └── Authenticates As: agenticUiIdentity
```

### Backend Dependencies
```
agentic-api (FastAPI)
    ├── Depends On: Azure OpenAI
    ├── Depends On: AI Foundry Project (optional)
    ├── Uses: Container Apps Environment
    ├── Logs To: Application Insights
    ├── Authenticates As: agenticApiIdentity
    └── Has Access To:
        ├── Cosmos DB (provisioned, unused)
        └── AI Search (provisioned, unused)
```

### Infrastructure Dependencies
```
Container Apps
    ├── Depends On: Container Registry (images)
    ├── Depends On: Container Apps Environment
    ├── Depends On: Managed Identities
    └── Depends On: Monitoring Stack

AI Services
    ├── Depends On: Resource Group
    └── Connected To: AI Search (via connection module)

Monitoring
    ├── Independent (created first)
    └── Referenced By: All services
```

---

## Inter-Component Communication

### 1. User → Frontend
- **Protocol**: HTTPS
- **Port**: 443 → 80 (Container Apps ingress)
- **Format**: HTTP/HTML/JSON

### 2. Frontend → Backend (Internal)
- **Protocol**: HTTP (internal Azure network)
- **Port**: 3000 → 8080
- **URL**: Dynamic via Aspire (local) or Container Apps DNS (prod)
- **Format**: AG-UI protocol over HTTP POST
- **Authentication**: None (internal network)

### 3. Backend → Azure OpenAI
- **Protocol**: HTTPS
- **Authentication**: Managed Identity (AAD token)
- **SDK**: Azure SDK for Python
- **Format**: OpenAI API protocol

### 4. Backend → Application Insights
- **Protocol**: HTTPS
- **Method**: OpenTelemetry SDK
- **Authentication**: Connection string (instrumentation key)
- **Data**: Logs, traces, metrics

---

## Component Lifecycles

### Frontend (agentic-ui)
```
1. Container Start
    ↓
2. Node.js runtime initialization
    ↓
3. Next.js standalone server starts
    ↓
4. Environment variables loaded (AGENT_API_URL)
    ↓
5. Port 3000 listening
    ↓
6. Ready to serve requests
```

### Backend (agentic-api)
```
1. Container Start
    ↓
2. Python runtime initialization
    ↓
3. Lifespan startup: OpenTelemetry configuration
    ↓
4. Environment variables validated (AZURE_OPENAI_*)
    ↓
5. AzureOpenAIChatClient initialization
    ↓
6. ChatAgent creation
    ↓
7. FastAPI endpoint registration
    ↓
8. Uvicorn server starts on port 8080
    ↓
9. Ready to serve requests
```

### Aspire Orchestrator (Local Dev)
```
1. dotnet run apphost.cs
    ↓
2. Load apphost.settings.json
    ↓
3. Start Backend (agentic-api)
    │   └── Wait for health check
    ↓
4. Start Frontend (agentic-ui)
    │   └── Inject AGENT_API_URL
    ↓
5. Dashboard available at localhost
    ↓
6. All services running with auto-restart
```

---

## Component Interfaces

### Frontend → Backend Interface (AG-UI Protocol)
**Endpoint**: `POST /`
**Content-Type**: `application/json`

**Request Schema** (inferred from CopilotKit):
```typescript
{
  message: string,
  context?: object,
  agent?: string,
  // ... (full schema from AG-UI protocol)
}
```

**Response Schema**:
```typescript
{
  response: string,
  // ... (full schema from Agent Framework)
}
```

### Backend → OpenAI Interface (Azure OpenAI SDK)
**Managed by**: Azure SDK
**Authentication**: Managed Identity Token
**Model**: gpt-5-mini
**Parameters**: Defined by Agent Framework (temperature, max_tokens, etc.)

---

## Component Configuration

### Frontend Configuration
**Sources**:
1. Environment Variables:
   - `AGENT_API_URL`
   - `APPLICATIONINSIGHTS_CONNECTION_STRING`
   - `AZURE_CLIENT_ID`
   - `PORT`
2. Build-Time Config:
   - `next.config.ts`
   - `tsconfig.json`
   - `eslint.config.mjs`

### Backend Configuration
**Sources**:
1. Environment Variables (Required):
   - `AZURE_OPENAI_ENDPOINT`
   - `AZURE_OPENAI_DEPLOYMENT_NAME`
2. Environment Variables (Optional):
   - `AZURE_CLIENT_ID`
   - `APPLICATIONINSIGHTS_CONNECTION_STRING`
   - `AZURE_COSMOS_ENDPOINT`
   - `AZURE_AI_SEARCH_ENDPOINT`
   - `AZURE_AI_PROJECT_ENDPOINT`
   - `PORT`
3. Code-Level Config:
   - Agent name: "AGUIAssistant"
   - Agent instructions: "You are a helpful assistant."

### Infrastructure Configuration
**Sources**:
1. Bicep Parameters:
   - `environmentName`
   - `location`
   - `aiDeploymentsLocation`
   - `principalId`
   - `principalType`
2. Bicep Variables:
   - Resource naming (via abbreviations.json)
   - SKUs and capacities
   - RBAC role definitions

---

## Component Boundaries

### Separation of Concerns

**Frontend Responsibilities**:
- User interface rendering
- User input collection
- API communication
- Response display
- Client-side routing

**Backend Responsibilities**:
- AI agent orchestration
- OpenAI API integration
- Authentication with Azure
- Telemetry emission
- Request validation

**Infrastructure Responsibilities**:
- Resource provisioning
- Network configuration
- Identity management
- Access control
- Monitoring setup

### What Each Component Does NOT Do

**Frontend Does NOT**:
- Call Azure OpenAI directly
- Manage authentication credentials
- Store persistent data
- Perform business logic

**Backend Does NOT**:
- Render UI
- Store session state (stateless)
- Manage infrastructure
- Handle user authentication (currently)

**Infrastructure Does NOT**:
- Contain application logic
- Store secrets (uses managed identity)
- Define application behavior

---

## Component Coupling Analysis

### Tight Coupling
❌ **Frontend → Backend URL**: Hardcoded dependency on AGENT_API_URL
❌ **Backend → OpenAI Model**: Specific to gpt-5-mini deployment
❌ **Aspire → File Paths**: Hardcoded paths to src/ directories

### Loose Coupling
✅ **Frontend → Backend Protocol**: AG-UI abstraction allows backend changes
✅ **Backend → AI Model**: Agent Framework abstracts model details
✅ **Infrastructure → Application**: Environment variable injection
✅ **Services → Identity**: Managed identity allows service changes

---

## Component Scaling Characteristics

| Component | Scaling Method | Trigger | Limit |
|-----------|----------------|---------|-------|
| Frontend | Horizontal (auto) | CPU/Memory/HTTP | 10 replicas |
| Backend | Horizontal (auto) | CPU/Memory/HTTP | 10 replicas |
| OpenAI | N/A (managed) | Rate limits | Quota-based |
| Cosmos DB | Automatic (serverless) | RU/s consumption | 5000 RU/s max |
| AI Search | Vertical (manual) | Admin action | Basic SKU limits |

---

## Component Failure Modes

### Frontend Failure Scenarios
1. **Backend Unavailable**: CopilotKit shows error, user sees message
2. **Container Restart**: New requests handled by other replicas
3. **Build Failure**: Deployment blocked, existing version continues

### Backend Failure Scenarios
1. **OpenAI API Failure**: Request fails, error returned to frontend
2. **Authentication Failure**: Container fails to start (fast fail)
3. **Configuration Missing**: Application exits with error

### Infrastructure Failure Scenarios
1. **Container Apps Environment Down**: All services unavailable
2. **Managed Identity Revoked**: Backend authentication fails
3. **OpenAI Deployment Deleted**: All agent requests fail

---

## Component Upgrade Paths

### Frontend Upgrades
1. Build new container image
2. Push to Azure Container Registry
3. Container Apps deploys new revision
4. Traffic gradually shifts (blue-green)

### Backend Upgrades
1. Update Python dependencies
2. Build and push new image
3. Container Apps blue-green deployment
4. Health check before traffic shift

### Infrastructure Upgrades
1. Update Bicep templates
2. Run `azd provision` or `az deployment` 
3. Azure applies changes (minimal downtime for PaaS)

---

## Conclusion

The application demonstrates **clean component separation** with:
- **Frontend**: Pure presentation layer with CopilotKit integration
- **Backend**: Focused AI agent orchestration
- **Infrastructure**: Declarative resource definitions

**Key Strengths**:
- Clear boundaries between components
- Environment-driven configuration
- Managed identity for security
- Loosely coupled via abstractions

**Key Weaknesses**:
- No persistent state (Cosmos DB unused)
- Tight coupling to specific URLs
- Limited error handling between components
- No circuit breakers or fallbacks

The architecture is **suitable for the reference implementation** but would benefit from additional resilience patterns for production deployment.
