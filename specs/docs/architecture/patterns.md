# Design Patterns and Conventions

## Overview

This document catalogs the design patterns, architectural patterns, coding conventions, and development practices employed in the agentic-shell-python application.

---

## Architectural Patterns

### 1. **Microservices Architecture**
**Implementation**: Frontend and backend as separate, independently deployable services

**Evidence**:
- Separate container apps for UI and API
- Independent scaling and deployment
- Clear service boundaries

**Benefits**:
- Independent scaling
- Technology diversity (React vs Python)
- Isolated failures

**Drawbacks**:
- Network latency between services
- Deployment complexity

---

### 2. **Backend for Frontend (BFF)**
**Implementation**: Next.js API route acts as an adapter between UI and backend

**Evidence**: `src/agentic-ui/app/api/copilotkit/route.ts`
```typescript
const runtime = new CopilotRuntime({
  agents: {
    my_agent: new HttpAgent({ 
      url: process.env.AGENT_API_URL 
    }),
  },
});
```

**Purpose**:
- Adapt AG-UI protocol for frontend consumption
- Handle client-specific concerns
- Centralize backend communication

---

### 3. **Agent Pattern (AI-Specific)**
**Implementation**: Microsoft Agent Framework `ChatAgent`

**Evidence**: `src/agentic-api/main.py`
```python
agent = ChatAgent(
    name="AGUIAssistant",
    instructions="You are a helpful assistant.",
    chat_client=chat_client,
)
```

**Characteristics**:
- Encapsulates AI behavior
- Separates instructions from implementation
- Enables tool integration (extensible)

---

### 4. **Adapter Pattern**
**Multiple Implementations**:

**a) HttpAgent (Frontend → Backend)**
```typescript
new HttpAgent({ url: process.env.AGENT_API_URL })
```
- Adapts backend API to CopilotKit interface

**b) AzureOpenAIChatClient (Backend → OpenAI)**
```python
AzureOpenAIChatClient(credential=..., endpoint=..., deployment_name=...)
```
- Adapts Azure OpenAI to Agent Framework interface

---

### 5. **Configuration Over Code**
**Implementation**: Environment variables for all configuration

**Evidence**:
- `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_DEPLOYMENT_NAME`
- `AGENT_API_URL`
- No hardcoded endpoints or secrets

**Benefits**:
- Environment-specific configuration
- Security (no secrets in code)
- Flexibility (change without rebuild)

---

### 6. **Infrastructure as Code (IaC)**
**Implementation**: Azure Bicep for all infrastructure

**Evidence**: `infra/*.bicep` files with parameterized templates

**Benefits**:
- Repeatable deployments
- Version-controlled infrastructure
- Consistency across environments

---

### 7. **Dependency Injection (Implicit)**
**Implementation**: Services receive dependencies via constructor/parameters

**Examples**:
- `ChatAgent` receives `chat_client`
- `AzureOpenAIChatClient` receives `credential`, `endpoint`, `deployment_name`
- `HttpAgent` receives `url`

**Benefits**:
- Testability (can mock dependencies)
- Flexibility (swap implementations)
- Separation of concerns

---

### 8. **Managed Identity Pattern (Azure-Specific)**
**Implementation**: No secrets, use Azure AD identities

**Evidence**: `infra/resources.bicep`
- User-assigned managed identities for container apps
- RBAC role assignments
- `AzureCliCredential()` for local dev

**Benefits**:
- No credential rotation needed
- Centralized access management
- Audit trail

---

## Design Patterns

### 1. **Provider Pattern (React)**
**Implementation**: `CopilotKit` provider wraps application

**Evidence**: `src/agentic-ui/app/layout.tsx`
```tsx
<CopilotKit runtimeUrl="/api/copilotkit" agent="my_agent">
  {children}
</CopilotKit>
```

**Purpose**:
- Share context across components
- Centralize configuration
- Enable deeply nested component access

---

### 2. **Facade Pattern**
**Implementation**: Agent Framework FastAPI endpoint

**Evidence**: `src/agentic-api/main.py`
```python
add_agent_framework_fastapi_endpoint(app, agent, "/")
```

**Purpose**:
- Simplifies complex agent interaction
- Hides protocol complexity
- Single interface for multiple operations

---

### 3. **Context Manager Pattern (Python)**
**Implementation**: Async lifespan management

**Evidence**: `src/agentic-api/main.py`
```python
@contextlib.asynccontextmanager
async def lifespan(app):
    telemetry.configure_opentelemetry()
    yield
```

**Purpose**:
- Setup/teardown resources
- Exception-safe resource management
- Clean lifecycle hooks

---

### 4. **Environment Strategy Pattern**
**Implementation**: Different behaviors based on environment

**Examples**:
- Local dev: `AzureCliCredential()`
- Production: Managed Identity (via `AZURE_CLIENT_ID`)
- Configuration via environment variables

---

### 5. **Factory Pattern (Implicit)**
**Implementation**: Aspire app builder

**Evidence**: `apphost.cs`
```csharp
var builder = DistributedApplication.CreateBuilder(args);
var api = builder.AddUvicornApp(...);
builder.AddJavaScriptApp(...);
```

**Purpose**:
- Create complex objects (services)
- Encapsulate service creation logic
- Fluent API for configuration

---

## Coding Conventions

### Python (Backend)

#### Module Structure
```python
# 1. Standard library imports
import contextlib
import logging
import os

# 2. Third-party imports
import fastapi
import telemetry

# 3. Local imports
from agent_framework import ChatAgent
from agent_framework.azure import AzureOpenAIChatClient
```

**Convention**: Grouped imports with blank lines between categories

#### Naming Conventions
- **Variables**: `snake_case` (e.g., `chat_client`, `deployment_name`)
- **Functions**: `snake_case` (e.g., `configure_opentelemetry`)
- **Classes**: `PascalCase` (e.g., `ChatAgent`, `AzureOpenAIChatClient`)
- **Constants**: `UPPER_SNAKE_CASE` (not present, but standard)
- **Private**: No leading underscore used (no private methods visible)

#### Error Handling
```python
if not endpoint:
    raise ValueError("AZURE_OPENAI_ENDPOINT environment variable is required")
```

**Pattern**: Fail-fast with descriptive errors

---

### TypeScript/JavaScript (Frontend)

#### Import Organization
```typescript
// 1. Framework imports
import { NextRequest } from "next/server";

// 2. Third-party libraries
import { CopilotRuntime, ... } from "@copilotkit/runtime";
import { HttpAgent } from "@ag-ui/client";

// 3. Local imports
import "./globals.css";
```

#### Naming Conventions
- **Variables**: `camelCase` (e.g., `serviceAdapter`, `runtime`)
- **Components**: `PascalCase` (e.g., `Page`, `RootLayout`)
- **Constants**: `camelCase` or `UPPER_SNAKE_CASE` (mixed usage)
- **Types/Interfaces**: `PascalCase` (e.g., `NextConfig`, `NextRequest`)

#### Component Structure
```tsx
export default function Page() {
  return (
    <Component>
      {/* JSX */}
    </Component>
  );
}
```

**Pattern**: Default export for page components

#### Client Directive
```tsx
"use client";
```
**Usage**: Top of files requiring client-side React features

---

### Bicep (Infrastructure)

#### Naming Conventions
- **Parameters**: `camelCase` (e.g., `environmentName`, `principalId`)
- **Variables**: `camelCase` (e.g., `abbrs`, `resourceToken`)
- **Resources**: `camelCase` (e.g., `containerRegistry`, `agenticApi`)

#### Resource Naming Pattern
```bicep
name: '${abbrs.resourceType}${resourceToken}'
```

**Examples**:
- `${abbrs.containerRegistryRegistries}${resourceToken}`
- `${abbrs.appManagedEnvironments}${resourceToken}`

**Benefits**: Consistent, unique, Azure-compliant names

#### Module Usage
```bicep
module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.0' = {
  name: 'monitoring'
  params: { ... }
}
```

**Pattern**: Azure Verified Modules from public registry

---

## Project Structure Conventions

### Frontend Structure
```
src/agentic-ui/
├── app/              # Next.js App Router (not pages/)
│   ├── layout.tsx    # Root layout (not _app.tsx)
│   ├── page.tsx      # Index route (not index.tsx)
│   ├── globals.css   # Global styles
│   └── api/          # API routes
└── public/           # Static assets
```

**Convention**: Next.js 16 App Router (latest structure)

### Backend Structure
```
src/agentic-api/
├── main.py           # Single entry point (flat structure)
└── pyproject.toml    # Modern Python project definition
```

**Convention**: Minimal structure, single file for simplicity

### Infrastructure Structure
```
infra/
├── main.bicep              # Entry point
├── resources.bicep         # Main resources
├── ai-project.bicep        # AI-specific resources
├── main.parameters.json    # Parameters
├── abbreviations.json      # Naming conventions
└── modules/                # Reusable modules
```

**Convention**: Modular Bicep with clear separation

---

## API Design Patterns

### RESTful Conventions
**Status**: **NOT FULLY APPLIED**

**Current Implementation**:
- Single endpoint: `POST /` (agent interaction)
- No CRUD operations
- No resource-based routing

**Reason**: Agent-centric API, not resource-centric

### RPC-Style API
**Implementation**: AG-UI protocol over HTTP POST

**Characteristics**:
- Action-oriented (send message, get response)
- Single endpoint for multiple operations
- Protocol-driven (not HTTP semantics)

**Example Flow**:
```
POST / 
Content-Type: application/json

{ "message": "Hello", "agent": "my_agent" }

→ Response: { "response": "Hello! How can I help?" }
```

---

## Error Handling Patterns

### Backend Error Handling
**Strategy**: Fail-fast validation

**Example**:
```python
if not endpoint:
    raise ValueError("AZURE_OPENAI_ENDPOINT environment variable is required")
```

**Characteristics**:
- Immediate failure on missing config
- Descriptive error messages
- No graceful degradation (by design)

### Frontend Error Handling
**Strategy**: Framework defaults

**Observation**:
- No explicit error boundaries in code
- React 19 default error handling
- CopilotKit handles agent errors

**Gap**: No custom error UI or logging

---

## State Management Patterns

### Frontend State
**Pattern**: React component state (local state)

**Evidence**:
- No Redux, Zustand, or MobX
- CopilotKit manages conversation state
- UI state is ephemeral

**Appropriate For**: Simple UI with limited state needs

### Backend State
**Pattern**: Stateless

**Characteristics**:
- No session storage
- No in-memory caches
- Each request is independent

**Implications**: Horizontal scaling friendly, no sticky sessions

---

## Security Patterns

### 1. **Zero Trust Identity**
**Implementation**: Managed Identity for all Azure service access

**Evidence**:
- No connection strings or API keys in code
- RBAC for fine-grained permissions
- Identity-based authentication

### 2. **Least Privilege**
**Implementation**: Minimal role assignments

**Evidence**:
- Specific roles (e.g., "Cognitive Services User", not "Owner")
- Per-service identities
- No global admin access

### 3. **Secrets Externalization**
**Implementation**: All secrets via environment variables or managed identity

**Evidence**:
- No `.env` files committed
- Environment variable validation
- Azure Key Vault (not used, but could be added)

---

## Testing Patterns

### Status: **NOT IMPLEMENTED**

**Expected Patterns** (based on tech stack):
- **Unit Tests**: Jest (frontend), pytest (backend)
- **Integration Tests**: API tests, component tests
- **E2E Tests**: Playwright (dependency present)

**Gap**: No test files or test infrastructure exists

---

## Logging and Observability Patterns

### Structured Logging (Backend)
```python
import logging
logger = logging.getLogger(__name__)
```

**Pattern**: Python standard logging module

**Destination**: Application Insights (via telemetry configuration)

### OpenTelemetry Pattern
```python
telemetry.configure_opentelemetry()
```

**Purpose**:
- Distributed tracing
- Automatic instrumentation
- Correlation IDs

### Metrics Pattern
**Implementation**: Implicit (Container Apps + Application Insights)

**Metrics Available**:
- HTTP request metrics
- Container resource metrics
- Custom metrics (if implemented)

---

## Deployment Patterns

### 1. **Blue-Green Deployment**
**Platform**: Azure Container Apps automatic

**Benefits**:
- Zero-downtime deployments
- Easy rollback
- Traffic shifting

### 2. **Immutable Infrastructure**
**Implementation**: Containers rebuilt on every change

**Benefits**:
- Consistent environments
- Reproducible builds
- No configuration drift

### 3. **Infrastructure as Code**
**Implementation**: Bicep templates

**Benefits**:
- Version-controlled infrastructure
- Automated provisioning
- Consistent environments

---

## Naming Conventions Summary

### Resources (Azure)
**Pattern**: `{abbreviation}-{resourceToken}`
**Example**: `ca-abc123def` (container app)

**Defined In**: `infra/abbreviations.json`

### Environment Variables
**Pattern**: `UPPER_SNAKE_CASE` with vendor prefixes
**Examples**:
- `AZURE_OPENAI_ENDPOINT`
- `APPLICATIONINSIGHTS_CONNECTION_STRING`
- `AGENT_API_URL`

### File Naming
**Frontend**: `kebab-case` or `PascalCase` (`.tsx`, `.ts`)
**Backend**: `snake_case.py`
**Config**: `kebab-case.json/yaml` or `camelCase.ts`

---

## Documentation Conventions

### README Structure
**Pattern**: Standard sections
- Overview
- Quick Start
- Architecture
- Workflow
- Contributing

### Code Comments
**Backend**: Minimal (code is self-documenting)
**Frontend**: Inline for non-obvious logic
**Infrastructure**: Descriptions on parameters and outputs

### Markdown
**Usage**: Ubiquitous for documentation
**Conventions**:
- Headers with ATX style (#)
- Code blocks with language tags
- Links to reference files

---

## Conventions Not Followed / Missing

### Code Style
❌ **No automated formatting**: No Black (Python) or Prettier (JS)
❌ **No linting enforced**: ESLint configured but no pre-commit hooks

### Testing
❌ **No test conventions**: No tests to establish patterns
❌ **No coverage requirements**: No quality gates

### Documentation
❌ **No API documentation**: No OpenAPI/Swagger spec
❌ **No inline API docs**: No docstrings (Python) or JSDoc (TypeScript)

### Git
❌ **No commit conventions**: No Conventional Commits
❌ **No branch naming**: No documented strategy
❌ **No PR templates**: No contribution guidelines

---

## Recommendations

### High Priority
1. **Add code formatters**: Black (Python), Prettier (TypeScript)
2. **Document APIs**: Generate OpenAPI spec
3. **Add inline documentation**: Docstrings and JSDoc
4. **Establish testing patterns**: Start with unit tests

### Medium Priority
5. **Git conventions**: Adopt Conventional Commits
6. **Error handling**: Custom error boundaries and logging
7. **Logging standards**: Structured logging with correlation IDs
8. **Security patterns**: Add input validation and rate limiting

### Low Priority
9. **Code review guidelines**: Document review process
10. **Performance patterns**: Add caching strategies
11. **Monitoring patterns**: Custom dashboards and alerts
12. **Accessibility patterns**: WCAG compliance for UI

---

## Conclusion

The application demonstrates **modern patterns** appropriate for cloud-native AI applications:

**Strong Patterns**:
- Microservices architecture
- Infrastructure as Code
- Managed Identity security
- Configuration over code
- Agent-based AI design

**Missing Patterns**:
- Testing patterns (no tests)
- Error handling patterns (minimal)
- Logging patterns (basic)
- Documentation patterns (no inline docs)

The patterns employed are **appropriate for a reference implementation** but would require expansion for production use, particularly in testing, error handling, and observability.
