# AGENTS.md

AI coding agent instructions for agentic-shell-python.

## Overview

| Aspect | Details |
|--------|---------|
| **Stack** | Python 3.11+ FastAPI backend, Next.js 16/React 19 frontend with CopilotKit |
| **Infra** | Azure Container Apps, OpenAI (gpt-5-mini), Cosmos DB, AI Search (unused) |
| **Status** | 50% production-ready: ❌ No auth, ❌ No tests, ❌ No rate limiting |
| **Cost** | ~$309/month ($74 wasted on unused Cosmos DB + AI Search) |

## Quick Start

```bash
# Recommended: Aspire orchestration
dotnet run --project apphost.cs
# Backend: localhost:8080 | Frontend: localhost:3000 | Dashboard: localhost:15888

# Or individually:
cd src/agentic-api && uv run fastapi dev main.py
cd src/agentic-ui && npm run dev

# Deploy to Azure
azd up
```

## Environment Variables

**Backend** (`src/agentic-api/.env`):
```bash
AZURE_OPENAI_ENDPOINT=https://<name>.openai.azure.com/
AZURE_OPENAI_DEPLOYMENT_NAME=gpt5MiniDeployment
```

**Frontend** (`src/agentic-ui/.env.local`):
```bash
AGENT_API_URL=http://localhost:8080
```

## Key Files

| Path | Purpose |
|------|---------|
| `src/agentic-api/main.py` | FastAPI + Agent Framework endpoint at `/` |
| `src/agentic-ui/app/page.tsx` | CopilotSidebar UI |
| `src/agentic-ui/app/api/copilotkit/route.ts` | BFF proxy to backend |
| `infra/main.bicep` | Subscription-scoped IaC entry point |
| `infra/resources.bicep` | Container Apps, Cosmos DB, AI Search |
| `apphost.cs` | .NET Aspire orchestration |

## Architecture

```
Browser → Next.js (/api/copilotkit) → FastAPI (/) → Azure OpenAI
```

- **BFF Pattern**: Frontend proxies to backend via CopilotKit runtime
- **Auth**: Azure Managed Identity (no secrets in code)
- **Stateless**: No conversation persistence (Cosmos DB provisioned but unused)

## Code Style

**Python**: PEP 8, 100-char lines, 4-space indent, type hints required, async functions
**TypeScript**: Airbnb style, 2-space indent, strict mode, explicit types
**Bicep**: 2-space indent, `@description()` on all params, Azure Verified Modules

## Common Commands

```bash
# Dependencies
cd src/agentic-api && uv pip install -e .
cd src/agentic-ui && npm install

# Linting
cd src/agentic-ui && npm run lint

# Build
cd src/agentic-ui && npm run build

# Deploy
azd up          # Full provision + deploy
azd deploy      # Code only
azd provision   # Infrastructure only
```

## Adding Resources

**Python dependency**: Add to `pyproject.toml`, run `uv pip install -e .`
**Node dependency**: `npm install <package>`
**Azure resource**: Add to `infra/resources.bicep`, run `azd provision`
**API endpoint**: Add to `src/agentic-api/main.py` (don't modify `/` - managed by agent framework)

## Debugging

| Issue | Solution |
|-------|----------|
| `AZURE_OPENAI_ENDPOINT not set` | Create `.env` file |
| `DefaultAzureCredential failed` | Run `az login` |
| `AGENT_API_URL undefined` | Create `.env.local` with `AGENT_API_URL=http://localhost:8080` |
| `429 Too Many Requests` | Wait 1 min or increase OpenAI quota |

**Logs**: `az containerapp logs show --name agentic-api --resource-group ${ENV}-rg --follow`

## Production Blockers

1. ❌ **No authentication** - Implement Azure AD B2C
2. ❌ **No rate limiting** - Add application-level or APIM
3. ❌ **No input validation** - Add Pydantic validation
4. ❌ **No tests** - Add pytest (backend), vitest (frontend)
5. ❌ **Public endpoints** - Configure private endpoints

## Documentation

Full specs at `specs/docs/`: architecture, security, APIs, databases, deployment guides.
