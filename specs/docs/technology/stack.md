# Technology Stack Documentation

## Overview

This document provides a complete inventory of all technologies, frameworks, libraries, and tools used in the agentic-shell-python application. This is a **spec2cloud** reference implementation demonstrating an AI-powered development workflow.

---

## Programming Languages

### Python
- **Version**: 3.11+ (as specified in `pyproject.toml`)
- **Usage**: Backend API implementation
- **Location**: `src/agentic-api/`
- **Purpose**: Powers the AI agent backend using FastAPI and Microsoft Agent Framework

### TypeScript/JavaScript
- **TypeScript Version**: ^5 (latest)
- **Node Version**: 20 (from dev container and Dockerfile)
- **Usage**: Frontend UI implementation
- **Location**: `src/agentic-ui/`
- **Purpose**: React-based web interface for the AI agent

### C# / .NET
- **Version**: .NET 9.0
- **Usage**: .NET Aspire orchestration
- **Location**: `apphost.cs`
- **Purpose**: Local development orchestration and service management

### Bicep
- **Version**: Latest (via Azure CLI)
- **Usage**: Infrastructure as Code
- **Location**: `infra/*.bicep`
- **Purpose**: Azure resource provisioning and management

---

## Backend Technologies

### Web Framework
- **FastAPI**: Latest (implicit via dependencies)
  - **Purpose**: HTTP API framework for Python
  - **Usage**: Hosts the AI agent endpoint at root path "/"
  - **Location**: `src/agentic-api/main.py`

### AI & Agent Framework
- **agent-framework-ag-ui**: >=1.0.0b251120
  - **Purpose**: Microsoft Agent Framework integration for AG-UI
  - **Core Components**:
    - `ChatAgent`: AI agent implementation
    - `AzureOpenAIChatClient`: Azure OpenAI integration
    - `add_agent_framework_fastapi_endpoint`: FastAPI endpoint registration
  - **Location**: `src/agentic-api/main.py`
  - **Configuration**: Uses Azure OpenAI with CLI credential authentication

### Authentication
- **azure.identity**: Implicit dependency
  - **Component**: `AzureCliCredential`
  - **Purpose**: Azure authentication for OpenAI access
  - **Usage**: Authenticates the agent framework with Azure services

### Telemetry
- **telemetry**: Custom module (source unknown - likely internal package)
  - **Purpose**: OpenTelemetry configuration
  - **Usage**: Configured in FastAPI lifespan context
  - **Location**: `src/agentic-api/main.py:38`

---

## Frontend Technologies

### Framework
- **Next.js**: 16.0.3
  - **Purpose**: React framework for production
  - **Configuration**: 
    - Standalone output mode (`next.config.ts`)
    - Server external packages: `pino`, `thread-stream`
    - Turbopack enabled
  - **Location**: `src/agentic-ui/`

### React
- **react**: 19.2.0
- **react-dom**: 19.2.0
  - **Purpose**: UI library and rendering
  - **Usage**: Client-side application interface

### CopilotKit Integration
- **@copilotkit/react-core**: ^1.10.6
  - **Purpose**: Core CopilotKit React functionality
  - **Usage**: Wraps application in `CopilotKit` provider
  - **Location**: `src/agentic-ui/app/layout.tsx`

- **@copilotkit/react-ui**: ^1.10.6
  - **Purpose**: CopilotKit UI components
  - **Components Used**: `CopilotSidebar`
  - **Location**: `src/agentic-ui/app/page.tsx`

- **@copilotkit/runtime**: ^1.10.6
  - **Purpose**: CopilotKit runtime and agent management
  - **Components**: `CopilotRuntime`, `ExperimentalEmptyAdapter`
  - **Location**: `src/agentic-ui/app/api/copilotkit/route.ts`

### AG-UI Integration
- **@ag-ui/client**: ^0.0.41
  - **Purpose**: Microsoft Agent Framework UI client
  - **Component**: `HttpAgent`
  - **Usage**: Connects to backend agent API
  - **Location**: `src/agentic-ui/app/api/copilotkit/route.ts`

- **@ag-ui/langgraph**: ^0.0.18
  - **Purpose**: LangGraph integration (not currently used in visible code)

### Styling
- **Tailwind CSS**: ^4
  - **Purpose**: Utility-first CSS framework
  - **Configuration**: PostCSS integration
  - **Location**: Global styles in `src/agentic-ui/app/globals.css`

- **@tailwindcss/postcss**: ^4
  - **Purpose**: PostCSS plugin for Tailwind

### Development Tools
- **TypeScript**: ^5
  - **Configuration**: `tsconfig.json` with strict mode
  - **Type Definitions**: 
    - `@types/node`: ^20
    - `@types/react`: ^19
    - `@types/react-dom`: ^19

- **ESLint**: ^9
  - **Configuration**: `eslint.config.mjs`
  - **Plugins**: `eslint-config-next` for Next.js best practices

---

## Orchestration & Development Environment

### .NET Aspire
- **Version**: 13.0.0
- **Purpose**: Local development orchestration
- **Packages Used**:
  - `Aspire.AppHost.Sdk@13.0.0`
  - `Aspire.Hosting.Python@13.0.0`
  - `Aspire.Hosting.JavaScript@13.0.0`
  - `Aspire.Hosting.Azure.CognitiveServices@13.0.0`
  - `Aspire.Hosting.Azure.AIFoundry@13.0.0-preview.1.25560.3`
- **Configuration**: `apphost.cs`, `apphost.settings.json`
- **Services Orchestrated**:
  - Python backend via Uvicorn
  - Next.js frontend via npm
  - Environment variable injection
  - Service-to-service communication

### Azure Developer CLI (azd)
- **Version**: Stable (from dev container)
- **Purpose**: Deployment orchestration
- **Configuration**: `azure.yaml`
- **Features Used**:
  - Service definitions
  - Container app hosting
  - Post-provision hooks

---

## Build Tools & Package Managers

### Python
- **uv**: Python package installer and runner
  - **Usage**: Aspire uses `.WithUv()` for Python app
  - **Purpose**: Fast Python package management

### Node.js
- **npm**: Default package manager
  - **Version**: Comes with Node 20
  - **Scripts**:
    - `dev`: Local development server
    - `build`: Production build
    - `start`: Production server
    - `lint`: ESLint execution
  - **Installation**: `npm ci` for reproducible builds

---

## Infrastructure & Cloud Services

### Azure Services (Provisioned)

#### Compute
- **Azure Container Apps**: 
  - Hosts both frontend and backend
  - Configuration in `infra/resources.bicep`
  - Min replicas: 1, Max replicas: 10

#### AI Services
- **Azure AI Foundry** (formerly AI Studio):
  - Project-based AI management
  - Configuration: `infra/ai-project.bicep`
  
- **Azure OpenAI**:
  - Model: gpt-5-mini
  - Deployment: GlobalStandard SKU, capacity 10
  - Version: 2025-08-07

#### Data & Search
- **Azure Cosmos DB**:
  - Serverless mode
  - Database: `agentic-storage`
  - SQL API with role-based access
  
- **Azure AI Search**:
  - SKU: Basic
  - Replica count: 1
  - Features: AAD auth with API key fallback

#### Observability
- **Azure Monitor**:
  - Log Analytics Workspace
  - Application Insights
  - Dashboard for monitoring

#### Container Registry
- **Azure Container Registry**:
  - Stores Docker images
  - Role assignments for managed identities

#### Identity
- **Managed Identities**:
  - System-assigned for AI services
  - User-assigned for container apps
  - RBAC roles:
    - Cognitive Services User
    - Azure AI Developer
    - Search Index Data Contributor
    - Search Service Contributor

---

## Development Container

### Base Image
- **Image**: `mcr.microsoft.com/devcontainers/python:1-3.12-bullseye`
- **Python Version**: 3.12 (for dev environment)

### Installed Features
- **Azure CLI**: Latest with Bicep support
- **TypeScript**: Latest via npm features
- **Azure Developer CLI**: Stable
- **Docker-in-Docker**: For container builds
- **.NET SDK**: 9.0
- **.NET Aspire**: Latest
- **MKDocs**: Latest with plugins:
  - mkdocs-material
  - pymdown-extensions
  - mkdocstrings[crystal,python]
  - mkdocs-monorepo-plugin
  - mkdocs-pdf-export-plugin
  - mkdocs-awesome-pages-plugin
  - mkdocs-minify-plugin
  - mkdocs-git-revision-date-localized-plugin

### VS Code Extensions
- GitHub Copilot Chat
- Azure Pack (ms-vscode.vscode-node-azure-pack)
- Windows AI Studio (ms-windows-ai-studio.windows-ai-studio)
- C# Dev Kit (ms-dotnettools.csdevkit)
- Aspire VS Code (microsoft-aspire.aspire-vscode)
- .NET Pack (ms-dotnettools.vscode-dotnet-pack)

### Post-Create Setup
- **APM CLI**: Installed via pip
- **Purpose**: Agent Package Manager for engineering standards

---

## APM (Agent Package Manager)

### Version
- **Configuration**: `apm.yml` v1.0.0

### Dependencies
- **danielmeppiel/azure-standards@1.0.0**
  - General engineering standards
  - Documentation patterns
  - Agent-first development
  - CI/CD practices
  - Security guidelines

### Workflow Scripts
Defined in `apm.yml`:
- `prd`: Product Requirements Document workflow
- `frd`: Feature Requirements Document workflow
- `plan`: Technical planning workflow
- `implement`: Implementation workflow
- `delegate`: GitHub Copilot delegation workflow
- `deploy`: Azure deployment workflow

---

## Model Context Protocol (MCP) Servers

Configuration in `.vscode/mcp.json`:

### HTTP-Based MCP Servers
- **context7**: Library documentation (`https://mcp.context7.com/mcp`)
- **github**: GitHub operations (`https://api.githubcopilot.com/mcp/`)
- **microsoft.docs.mcp**: Microsoft docs (`https://learn.microsoft.com/api/mcp`)
- **deepwiki**: Repository understanding (`https://mcp.deepwiki.com/sse`)
- **copilotkit**: CopilotKit integration (`https://mcp.copilotkit.ai/sse`)

### STDIO-Based MCP Servers
- **playwright**: Browser automation (`npx @playwright/mcp@latest`)

---

## Docker Configuration

### Backend Container
**Not explicitly defined** - Uses Aspire container generation

### Frontend Container
**Dockerfile**: `src/agentic-ui/Dockerfile`
- **Base**: Node 20-slim
- **Build Strategy**: Multi-stage
  1. Dependencies stage: `npm install`
  2. Builder stage: `npm build` with Linux x64 native binaries
  3. Runner stage: Minimal production image
- **Output**: Next.js standalone mode
- **Port**: 3000
- **User**: Non-root (nextjs:nodejs, UID 1001:GID 1001)

---

## CI/CD & Deployment

### Azure Developer CLI
- **Configuration**: `azure.yaml`
- **Services**:
  - `agentic-api`: Python, Container App, Port 8080
  - `agentic-ui`: TypeScript, Container App, Port 80 (maps to 3000 internally)
  
### Post-Provision Hooks
- **Script**: `infra/scripts/postprovision.sh` (POSIX)
- **Purpose**: Configures `apphost.settings.json` with Azure OpenAI endpoints
- **Tools**: Uses `jq` for JSON manipulation (with sed fallback)

---

## Testing Infrastructure

### Status: NOT IMPLEMENTED
- **Test Frameworks**: Playwright is referenced in package-lock.json (`@playwright/test`) but no test files exist
- **Test Coverage**: None identified in the codebase
- **Test Directories**: No `test/`, `tests/`, `__tests__/` directories found
- **Unit Tests**: Not implemented
- **Integration Tests**: Not implemented
- **E2E Tests**: Not implemented

---

## Documentation Tools

### MKDocs
- **Purpose**: Project documentation generation
- **Configuration**: Expected at `mkdocs.yml` (not present in current snapshot)
- **Plugins**: Comprehensive set installed in dev container
- **Standards**: Defined in engineering standards packages

---

## Version Control & Collaboration

### Git
- **Repository**: EmeaAppGbb/agentic-shell-python
- **Branch**: main (also default branch)
- **Ignore Patterns**: Standard for Node.js, Python, .NET, Azure

### GitHub Integration
- **Agents**: Defined in `.github/agents/`
  - PM Agent (Product Manager)
  - Dev Lead Agent (Technical Lead)
  - Dev Agent (Developer)
  - Azure Agent (Cloud Architect)
  - Tech Analyst Agent (Reverse Engineering)
  - Modernizer Agent (Modernization Strategy)
  - Planner Agent (Planning-only)
  - Architect Agent

- **Prompts**: Defined in `.github/prompts/`
  - PRD, FRD, Plan, Implement, Delegate, Deploy
  - ADR (Architecture Decision Records)
  - Generate Agents, Modernize, Reverse Engineering

---

## Environment Variables

### Backend (agentic-api)
**Required**:
- `AZURE_OPENAI_ENDPOINT`: Azure OpenAI service endpoint
- `AZURE_OPENAI_DEPLOYMENT_NAME`: Model deployment name (e.g., gpt5MiniDeployment)
- `AZURE_CLIENT_ID`: Managed identity client ID
- `PORT`: API port (8080)

**Optional**:
- `APPLICATIONINSIGHTS_CONNECTION_STRING`: Telemetry
- `AZURE_COSMOS_ENDPOINT`: Cosmos DB endpoint (provisioned but not used in code)
- `AZURE_AI_SEARCH_ENDPOINT`: AI Search endpoint (provisioned but not used in code)
- `AZURE_AI_PROJECT_ENDPOINT`: AI Foundry project endpoint

### Frontend (agentic-ui)
**Required**:
- `AGENT_API_URL`: Backend API URL (e.g., `http://localhost:5149` or production URL)
- `PORT`: UI port (3000)

**Optional**:
- `APPLICATIONINSIGHTS_CONNECTION_STRING`: Telemetry
- `AZURE_CLIENT_ID`: Managed identity client ID

---

## Configuration Files Reference

### Python
- `src/agentic-api/pyproject.toml`: Python project metadata and dependencies

### TypeScript/Node.js
- `src/agentic-ui/package.json`: NPM dependencies and scripts
- `src/agentic-ui/package-lock.json`: Dependency lock file
- `src/agentic-ui/tsconfig.json`: TypeScript compiler options
- `src/agentic-ui/next.config.ts`: Next.js configuration
- `src/agentic-ui/eslint.config.mjs`: ESLint configuration
- `src/agentic-ui/postcss.config.mjs`: PostCSS configuration

### Infrastructure
- `infra/main.bicep`: Main infrastructure template
- `infra/resources.bicep`: Resource definitions
- `infra/ai-project.bicep`: AI Foundry configuration
- `infra/main.parameters.json`: Deployment parameters
- `infra/abbreviations.json`: Azure resource name abbreviations

### Orchestration
- `apphost.cs`: .NET Aspire app host
- `apphost.settings.json`: Aspire runtime settings
- `apphost.settings.template.json`: Settings template
- `azure.yaml`: Azure Developer CLI configuration

### Development
- `.devcontainer/devcontainer.json`: Dev container configuration
- `.vscode/mcp.json`: MCP server configuration
- `.vscode/launch.json`: Debug configurations (present but not analyzed)
- `apm.yml`: APM package manager configuration

---

## Notable Absences

### Missing Components
- **Database ORM**: No SQLAlchemy, Prisma, or Entity Framework usage detected
- **State Management**: No Redux, Zustand, or MobX in frontend
- **API Documentation**: No OpenAPI/Swagger specification
- **Testing Libraries**: Jest, Pytest, xUnit not configured
- **Linting (Backend)**: No Black, Flake8, or Pylint configuration
- **API Gateway**: Direct container app exposure
- **CDN**: No Azure CDN or Front Door
- **Secrets Management**: Relies on managed identity; no Azure Key Vault integration visible

### Provisioned but Unused Services
- **Azure Cosmos DB**: Database created but no code accesses it
- **Azure AI Search**: Service provisioned but no indexing or search operations

---

## Dependency Management Strategy

### Frontend
- **Lock File**: `package-lock.json` ensures reproducible builds
- **Installation**: `npm ci` in CI/CD and Docker builds
- **Update Strategy**: Not defined; manual updates required

### Backend
- **Lock File**: No `requirements.txt` or `poetry.lock`; relies on version constraints in `pyproject.toml`
- **Risk**: Potential for dependency drift without pinned versions
- **Package Manager**: Uses `uv` for speed

### Infrastructure
- **Bicep Modules**: Uses Azure Verified Modules (AVM) from `br/public` registry
- **Versioning**: Specific versions pinned (e.g., `@0.8.0`, `@0.1.1`)

---

## Technology Modernization Notes

### Current State Assessment
- **Modern Stack**: Latest versions of major frameworks (React 19, Next.js 16, .NET 9)
- **AI-First**: Built on cutting-edge Microsoft Agent Framework
- **Cloud-Native**: Container-based, Azure-native architecture
- **Developer Experience**: Excellent with Aspire orchestration and dev containers

### Potential Improvements
- **Testing**: Currently no test coverage
- **Database Usage**: Cosmos DB provisioned but not utilized
- **Search Integration**: AI Search provisioned but not integrated
- **API Documentation**: No OpenAPI specification
- **Backend Locking**: Python dependencies not locked to specific versions
- **Monitoring**: Application Insights configured but usage not evident in code
- **Secrets**: No Key Vault integration for sensitive configuration

---

## Summary

This is a **modern, cloud-native AI agent application** built with:
- **Backend**: Python + FastAPI + Microsoft Agent Framework + Azure OpenAI
- **Frontend**: React 19 + Next.js 16 + CopilotKit + Tailwind CSS
- **Orchestration**: .NET Aspire for local dev, Azure Container Apps for production
- **Infrastructure**: Azure Bicep with Verified Modules
- **Development**: Comprehensive dev container with APM-based workflow automation
- **AI Integration**: Tight integration with Azure AI Foundry and OpenAI models

The application is a **reference implementation** of the spec2cloud workflow, demonstrating AI-powered development patterns from specification to deployment.
