# Dependencies Analysis

## Overview

This document provides a comprehensive analysis of all dependencies used in the agentic-shell-python application, including versions, purposes, security considerations, and maintenance implications.

---

## Backend Dependencies (Python)

### Direct Dependencies

#### agent-framework-ag-ui
- **Version**: >=1.0.0b251120
- **Type**: Beta/Preview
- **Purpose**: Microsoft Agent Framework integration for AG-UI compatibility
- **Sub-packages Provided**:
  - `agent_framework`: Core agent functionality
  - `agent_framework.azure`: Azure OpenAI integration
  - `agent_framework_ag_ui`: FastAPI endpoint integration
- **Risk Level**: **HIGH** (Beta version, pre-1.0)
- **Maintenance**: Active development by Microsoft
- **Security**: Trusted source (Microsoft)
- **Location**: `src/agentic-api/pyproject.toml`
- **Transitive Dependencies**: Not explicitly documented (includes FastAPI, Azure SDK, OpenTelemetry)

### Implicit/Transitive Dependencies

#### FastAPI
- **Version**: Not pinned (transitive from agent-framework-ag-ui)
- **Purpose**: HTTP API framework
- **Usage**: Main application server in `src/agentic-api/main.py`
- **Risk**: Version drift possible without lock file

#### azure-identity
- **Version**: Not pinned (transitive)
- **Purpose**: Azure authentication
- **Component Used**: `AzureCliCredential`
- **Security**: Critical for Azure resource access

#### telemetry (Custom Module)
- **Version**: Unknown
- **Purpose**: OpenTelemetry configuration
- **Source**: Unclear - possibly bundled with agent-framework-ag-ui
- **Risk**: Undocumented dependency

### Python Standard Library
- **contextlib**: Async context managers
- **logging**: Application logging
- **os**: Environment variable access

---

## Frontend Dependencies (JavaScript/TypeScript)

### Production Dependencies

#### CopilotKit Ecosystem
**@copilotkit/react-core**: ^1.10.6
- **Purpose**: Core React integration for CopilotKit
- **Usage**: Provider component in layout
- **Update Frequency**: Active (1.x indicates stable API)
- **License**: Check package for specifics

**@copilotkit/react-ui**: ^1.10.6
- **Purpose**: Pre-built UI components
- **Components Used**: `CopilotSidebar`
- **Styling**: Requires `@copilotkit/react-ui/styles.css`

**@copilotkit/runtime**: ^1.10.6
- **Purpose**: Runtime agent management
- **Components**: `CopilotRuntime`, `ExperimentalEmptyAdapter`
- **Risk**: "Experimental" API may have breaking changes

#### Microsoft Agent Framework UI
**@ag-ui/client**: ^0.0.41
- **Purpose**: HTTP client for Microsoft Agent Framework
- **Version Status**: Pre-1.0, rapidly evolving (0.0.x)
- **Risk Level**: **HIGH** (Unstable API)
- **Component**: `HttpAgent` for backend communication

**@ag-ui/langgraph**: ^0.0.18
- **Purpose**: LangGraph integration
- **Current Usage**: **NOT USED** in visible code
- **Risk**: Unnecessary dependency, potential bloat
- **Recommendation**: Consider removing if truly unused

#### React Ecosystem
**react**: 19.2.0
- **Version Status**: Latest stable (React 19 released Dec 2024)
- **Major Version**: Breaking changes from 18.x
- **Features**: New concurrent features, Server Components
- **Risk**: Ecosystem catching up to React 19

**react-dom**: 19.2.0
- **Purpose**: DOM rendering for React
- **Peer Dependency**: Must match React version

#### Next.js
**next**: 16.0.3
- **Release**: Recent (Next.js 16 in 2024)
- **Stability**: Production-ready
- **Features Used**:
  - App Router (app/ directory)
  - Standalone output
  - API routes
  - Turbopack (enabled in config)
- **Maintenance**: Actively maintained by Vercel

### Development Dependencies

#### Styling
**tailwindcss**: ^4
- **Version Status**: Major version 4 (recently released)
- **Purpose**: Utility CSS framework
- **Risk**: v4 is new, potential breaking changes
- **Integration**: PostCSS plugin

**@tailwindcss/postcss**: ^4
- **Purpose**: PostCSS integration for Tailwind v4
- **Dependency**: Required for Tailwind v4

#### TypeScript
**typescript**: ^5
- **Version**: Latest TypeScript 5.x
- **Purpose**: Type checking and compilation
- **Configuration**: Strict mode enabled

**@types/node**: ^20
- **Purpose**: Node.js type definitions
- **Compatibility**: Matches Node 20 runtime

**@types/react**: ^19
- **Purpose**: React type definitions
- **Version**: Matches React 19

**@types/react-dom**: ^19
- **Purpose**: React DOM type definitions
- **Version**: Matches React DOM 19

#### Linting
**eslint**: ^9
- **Version**: Latest ESLint 9.x
- **Configuration**: `eslint.config.mjs` (flat config)
- **Purpose**: Code quality and consistency

**eslint-config-next**: 16.0.3
- **Purpose**: Next.js ESLint rules
- **Version**: Matches Next.js version

---

## Infrastructure Dependencies (Bicep)

### Azure Verified Modules (AVM)

#### Monitoring
**br/public:avm/ptn/azd/monitoring:0.1.0**
- **Purpose**: Log Analytics, Application Insights, Dashboard
- **Stability**: 0.1.0 (Early release)
- **Components**: Complete monitoring stack

#### Container Registry
**br/public:avm/res/container-registry/registry:0.1.1**
- **Purpose**: Azure Container Registry
- **Patch Version**: Bug fixes over 0.1.0

#### Container Apps
**br/public:avm/res/app/managed-environment:0.4.5**
- **Purpose**: Container Apps Environment
- **Maturity**: 0.4.x indicates active development

**br/public:avm/res/app/container-app:0.8.0**
- **Purpose**: Individual container app definitions
- **Maturity**: 0.8.x nearing 1.0

#### Cosmos DB
**br/public:avm/res/document-db/database-account:0.8.1**
- **Purpose**: Cosmos DB account and databases
- **Version**: Mature pre-1.0

#### AI Search
**br/public:avm/res/search/search-service:0.10.0**
- **Purpose**: Azure AI Search service
- **Version**: Nearing 1.0 release

#### Managed Identity
**br/public:avm/res/managed-identity/user-assigned-identity:0.2.1**
- **Purpose**: User-assigned managed identities
- **Stability**: Early release

### Custom Bicep Modules
- **Location**: `infra/modules/`
- **ai-search-conn.bicep**: Connects AI Search to AI Foundry
- **fetch-container-image.bicep**: Retrieves latest container images

---

## Orchestration Dependencies

### .NET Aspire Packages

**Aspire.AppHost.Sdk**: 13.0.0
- **Purpose**: Aspire SDK for app host
- **Status**: Production release (13.x)

**Aspire.Hosting.Python**: 13.0.0
- **Purpose**: Python app hosting support
- **Methods Used**: `AddUvicornApp`, `WithUv`

**Aspire.Hosting.JavaScript**: 13.0.0
- **Purpose**: JavaScript/Node.js hosting
- **Methods Used**: `AddJavaScriptApp`, `WithNpm`, `WithRunScript`

**Aspire.Hosting.Azure.CognitiveServices**: 13.0.0
- **Purpose**: Azure AI services integration

**Aspire.Hosting.Azure.AIFoundry**: 13.0.0-preview.1.25560.3
- **Status**: **PREVIEW** version
- **Risk**: Preview API, potential breaking changes
- **Purpose**: Azure AI Foundry integration

---

## Development Container Dependencies

### System Tools
- **Azure CLI**: Latest (with Bicep)
- **Azure Developer CLI**: Stable
- **Docker**: Latest with Docker-in-Docker
- **.NET SDK**: 9.0
- **APM CLI**: Installed via pip

### MKDocs Plugins
- mkdocs-material: Material theme
- pymdown-extensions: Markdown extensions
- mkdocstrings[crystal,python]: API documentation
- mkdocs-monorepo-plugin: Multi-repo support
- mkdocs-pdf-export-plugin: PDF generation
- mkdocs-awesome-pages-plugin: Page organization
- mkdocs-minify-plugin: Asset minification
- mkdocs-git-revision-date-localized-plugin: Git integration

---

## APM Dependencies

### Engineering Standards
**danielmeppiel/azure-standards**: 1.0.0
- **Source**: GitHub (danielmeppiel/azure-standards)
- **Purpose**: General Azure engineering standards
- **Includes**:
  - Documentation guidelines
  - Agent-first patterns
  - CI/CD practices
  - Security standards
- **Version**: Locked to 1.0.0

---

## Security Analysis

### High-Risk Dependencies

1. **agent-framework-ag-ui** (>=1.0.0b251120)
   - **Issue**: Beta version, API instability
   - **Impact**: Core backend functionality
   - **Mitigation**: Lock to specific version when stable

2. **@ag-ui/client** (^0.0.41) and **@ag-ui/langgraph** (^0.0.18)
   - **Issue**: Pre-1.0, rapid version changes
   - **Impact**: Frontend-backend communication
   - **Mitigation**: Monitor for 1.0 release, use caret (^) for updates

3. **Aspire.Hosting.Azure.AIFoundry** (preview)
   - **Issue**: Preview version
   - **Impact**: AI Foundry integration may break
   - **Mitigation**: Monitor for stable release

### Moderate-Risk Dependencies

1. **Tailwind CSS v4**
   - **Issue**: Recently released major version
   - **Impact**: Styling framework
   - **Mitigation**: Ecosystem adoption increasing

2. **React 19**
   - **Issue**: Latest major version
   - **Impact**: Core UI library
   - **Mitigation**: Stable but ecosystem catching up

3. **Next.js 16**
   - **Issue**: Recent release
   - **Impact**: Framework foundation
   - **Mitigation**: Vercel actively maintains

### Missing Security Measures

1. **No Python Lock File**
   - **Risk**: Dependency version drift
   - **Recommendation**: Add `requirements.txt` or `poetry.lock`

2. **No Dependency Scanning**
   - **Risk**: Vulnerable packages undetected
   - **Recommendation**: Add Dependabot or Snyk

3. **No SBOM (Software Bill of Materials)**
   - **Risk**: Compliance and audit challenges
   - **Recommendation**: Generate SBOM in CI/CD

---

## Maintenance Considerations

### Update Frequency

#### Critical (Monitor Weekly)
- **agent-framework-ag-ui**: Beta status, frequent updates
- **@ag-ui/\***: Pre-1.0, API changes
- **@copilotkit/\***: Active development

#### Regular (Monitor Monthly)
- **next**, **react**, **react-dom**: Framework updates
- **Azure Verified Modules**: Regular improvements
- **@types/\***: Type definition updates

#### Stable (Monitor Quarterly)
- **tailwindcss**: Mature but major version new
- **.NET Aspire**: Production release
- **Azure CLI/azd**: Stable tooling

### Breaking Change Risk

**High Risk**:
- All `0.0.x` versions (@ag-ui packages)
- Beta versions (agent-framework-ag-ui)
- Preview versions (Aspire AI Foundry)

**Medium Risk**:
- `0.x.x` versions (Azure Verified Modules)
- Recently released major versions (React 19, Tailwind v4)

**Low Risk**:
- `1.x.x` stable versions (@copilotkit)
- Mature frameworks (Next.js, TypeScript)

---

## Dependency Graph Summary

```
Frontend (agentic-ui)
├── next@16.0.3
│   ├── react@19.2.0
│   └── react-dom@19.2.0
├── @copilotkit/* @1.10.6
│   └── @ag-ui/client@0.0.41 → Backend API
├── tailwindcss@4
└── Dev: typescript@5, eslint@9

Backend (agentic-api)
├── agent-framework-ag-ui@1.0.0b251120
│   ├── fastapi (implicit)
│   ├── azure-identity (implicit)
│   └── telemetry (implicit)
└── Python 3.11+

Infrastructure
├── Azure Verified Modules (0.x versions)
├── .NET Aspire 13.0.0
└── Azure AI Foundry (preview)
```

---

## Recommendations

### Immediate Actions
1. **Add Python lock file** (e.g., `requirements.txt` with exact versions)
2. **Remove unused dependency** (@ag-ui/langgraph if not needed)
3. **Document telemetry module** source and version

### Short-Term (1-3 months)
1. **Monitor for stable releases**:
   - agent-framework-ag-ui 1.0.0
   - @ag-ui packages 1.0.0
   - Aspire AI Foundry stable
2. **Add dependency scanning** (Dependabot/Snyk)
3. **Generate SBOM** for compliance

### Long-Term (3-6 months)
1. **Review React 19 ecosystem** maturity
2. **Evaluate Tailwind v4** stability
3. **Audit Azure Verified Modules** for 1.0 releases
4. **Implement automated dependency updates**

---

## Version Compatibility Matrix

| Component | Python | Node | React | Next.js | Azure SDK |
|-----------|--------|------|-------|---------|-----------|
| Backend   | ≥3.11  | N/A  | N/A   | N/A     | Latest    |
| Frontend  | N/A    | 20   | 19.2  | 16.0    | N/A       |
| Dev Container | 3.12 | 20 | N/A   | N/A     | Latest    |

---

## Conclusion

The application uses a **modern but bleeding-edge** dependency stack. Key risks include:
- Beta/preview versions in critical paths
- Multiple pre-1.0 dependencies
- Missing lock file for Python dependencies
- No automated security scanning

The stack is **functional and well-architected** but requires **active monitoring** and **prompt updates** as dependencies reach stable releases.
