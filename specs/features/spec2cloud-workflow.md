# Feature: Spec2Cloud Development Workflow

## Feature Overview

**Feature Name**: Spec2Cloud AI-Powered Development Workflow
**Primary User**: Development teams, technical leads, product managers
**Business Purpose**: Automate and streamline the process of transforming product ideas into deployed Azure applications using AI agents

---

## Feature Description

Spec2Cloud is a structured, agent-driven development workflow that guides teams from high-level product concepts through specification, planning, implementation, and deployment. It uses specialized GitHub Copilot agents with distinct roles to automate different phases of the software development lifecycle.

---

## User Workflows

### Workflow 1: Product Requirements Definition (`/prd`)

1. **User initiates PRD workflow**
   - Runs: `apm run prd` or invokes PM agent with `/prd` prompt
   - PM Agent engages in conversation

2. **PM Agent asks clarifying questions**
   - Understands product vision
   - Identifies business goals
   - Determines scope and constraints
   - Captures user stories

3. **PM Agent creates PRD**
   - Generates `specs/prd.md`
   - Documents goals, scope, requirements, user stories
   - Creates living document for iteration

4. **User reviews and refines**
   - Provides feedback to PM Agent
   - Iterates on PRD content
   - Finalizes when satisfied

---

### Workflow 2: Feature Requirements Decomposition (`/frd`)

1. **User initiates FRD workflow**
   - Prerequisite: PRD must exist
   - Runs: `apm run frd` or invokes PM agent with `/frd` prompt

2. **PM Agent analyzes PRD**
   - Breaks down into individual features
   - Identifies functional areas

3. **PM Agent creates feature documents**
   - Generates `specs/features/{feature-name}.md` for each feature
   - Defines inputs, outputs, dependencies
   - Documents acceptance criteria

4. **User validates features**
   - Reviews feature breakdown
   - Provides additional requirements
   - Confirms completeness

---

### Workflow 3: Engineering Standards Generation (`/generate-agents`)

1. **User initiates standards generation** (optional early, required before implementation)
   - Runs: `apm run generate-agents` or uses prompt

2. **System checks APM installation**
   - Installs APM CLI if missing
   - Runs `apm install` to fetch packages

3. **APM compiles standards**
   - Reads all packages from `apm.yml`
   - Consolidates into `AGENTS.md`
   - Creates comprehensive engineering guidelines

4. **AGENTS.md generated**
   - Located at project root
   - Contains all engineering standards
   - Used by Dev and Dev Lead agents

---

### Workflow 4: Technical Planning (`/plan`)

1. **User initiates planning**
   - Prerequisite: FRDs exist, AGENTS.md generated
   - Runs: `apm run plan` or invokes Dev agent with `/plan` prompt

2. **Dev Agent analyzes FRDs**
   - Reviews feature requirements
   - Considers AGENTS.md standards
   - Identifies technical tasks

3. **Dev Agent creates task breakdown**
   - Generates `specs/tasks/{task-name}.md` for each task
   - Defines implementation details
   - Identifies dependencies and complexity
   - Specifies scaffolding needs

4. **User validates plan**
   - Reviews technical approach
   - Confirms alignment with requirements
   - Approves for implementation

---

### Workflow 5: Implementation (`/implement` OR `/delegate`)

#### Option A: Local Implementation (`/implement`)

1. **User chooses local implementation**
   - Runs: `apm run implement` or invokes Dev agent

2. **Dev Agent implements code**
   - Writes code in `src/backend` and `src/frontend`
   - Follows AGENTS.md standards
   - Implements tasks from specs/tasks/

3. **Dev Agent creates/updates files**
   - Uses code generation tools
   - Applies architectural patterns
   - Adds necessary tests (if configured)

4. **User reviews and tests**
   - Runs code locally
   - Validates functionality
   - Provides feedback for refinement

#### Option B: Delegation to GitHub Copilot (`/delegate`)

1. **User chooses delegation**
   - Runs: `apm run delegate` or invokes Dev agent

2. **Dev Agent creates GitHub Issues**
   - Generates detailed issue for each task
   - Includes full context and acceptance criteria
   - Tags appropriately

3. **Dev Agent assigns to Copilot Coding Agent**
   - Uses GitHub's Copilot agent feature
   - Provides all necessary context

4. **Copilot Coding Agent implements**
   - Works autonomously on issues
   - Creates pull requests
   - User reviews and merges

---

### Workflow 6: Azure Deployment (`/deploy`)

1. **User initiates deployment**
   - Prerequisite: Code implemented and tested
   - Runs: `apm run deploy` or invokes Azure agent

2. **Azure Agent analyzes codebase**
   - Identifies required Azure services
   - Reviews AGENTS.md for infrastructure decisions
   - Consults ADRs (Architecture Decision Records) if present

3. **Azure Agent generates IaC**
   - Creates Bicep templates in `infra/`
   - Uses Azure Verified Modules
   - Follows Azure best practices

4. **Azure Agent creates CI/CD**
   - Generates GitHub Actions workflows
   - Configures deployment automation

5. **Azure Agent deploys to Azure**
   - Uses Azure Developer CLI (azd)
   - Provisions resources
   - Deploys applications
   - Configures monitoring

6. **Application live on Azure**
   - Production-ready deployment
   - Monitoring configured
   - URLs provided to user

---

## Functional Requirements

### FR-1: PM Agent - PRD Generation
**Description**: PM Agent creates Product Requirements Documents
**Implementation**: `.github/agents/pm.agent.md` + `.github/prompts/prd.prompt.md`
**Status**: ✅ Defined (not tested in current codebase)

**Capabilities**:
- Conversational requirements gathering
- Structured PRD generation
- Iterative refinement
- Living documentation

---

### FR-2: PM Agent - FRD Decomposition
**Description**: PM Agent breaks PRD into Feature Requirements Documents
**Implementation**: `.github/agents/pm.agent.md` + `.github/prompts/frd.prompt.md`
**Status**: ✅ Defined

**Capabilities**:
- PRD analysis
- Feature identification
- Acceptance criteria definition
- Dependency mapping

---

### FR-3: Dev Lead Agent - Standards Review
**Description**: Dev Lead reviews architecture and ensures standards adherence
**Implementation**: `.github/agents/devlead.agent.md`
**Status**: ✅ Defined

**Capabilities**:
- Architecture review
- Pattern validation
- AGENTS.md compliance checking
- Technical guidance

---

### FR-4: APM - Standards Management
**Description**: APM manages engineering standards packages
**Implementation**: `apm.yml` + APM CLI
**Status**: ✅ Implemented

**Capabilities**:
- Package installation
- Version management
- Standards compilation
- AGENTS.md generation

---

### FR-5: Dev Agent - Technical Planning
**Description**: Dev Agent creates technical task breakdowns
**Implementation**: `.github/agents/dev.agent.md` + `.github/prompts/plan.prompt.md`
**Status**: ✅ Defined

**Capabilities**:
- FRD analysis
- Task generation
- Dependency identification
- Complexity estimation

---

### FR-6: Dev Agent - Implementation
**Description**: Dev Agent implements code or delegates to GitHub Copilot
**Implementation**: `.github/agents/dev.agent.md` + `.github/prompts/implement.prompt.md` + `.github/prompts/delegate.prompt.md`
**Status**: ✅ Defined

**Capabilities**:
- Code generation
- Pattern application
- Testing (if configured)
- GitHub Issue creation
- Copilot assignment

---

### FR-7: Azure Agent - Infrastructure Generation
**Description**: Azure Agent generates Bicep IaC templates
**Implementation**: `.github/agents/azure.agent.md` + `.github/prompts/deploy.prompt.md`
**Status**: ✅ Demonstrated (current codebase has Bicep)

**Capabilities**:
- Codebase analysis
- Service identification
- Bicep generation
- Azure Verified Modules usage

---

### FR-8: Azure Agent - CI/CD Generation
**Description**: Azure Agent creates GitHub Actions workflows
**Implementation**: `.github/agents/azure.agent.md`
**Status**: ⚠️ Defined (no workflows in current repo)

**Expected**:
- Build workflows
- Test workflows
- Deployment workflows
- Environment configuration

---

### FR-9: Azure Agent - Deployment Orchestration
**Description**: Azure Agent deploys to Azure using azd
**Implementation**: `.github/agents/azure.agent.md`
**Status**: ✅ Demonstrated (azure.yaml configured)

**Capabilities**:
- azd provisioning
- Resource deployment
- Configuration injection
- Post-provision hooks

---

### FR-10: Tech Analyst Agent - Reverse Engineering
**Description**: Tech Analyst analyzes existing codebases
**Implementation**: `.github/agents/tech-analyst.agent.md` + `.github/prompts/rev-eng.prompt.md`
**Status**: ✅ Defined (this analysis is an example)

**Capabilities**:
- Technology stack analysis
- Architecture documentation
- Feature extraction
- Technical documentation generation

---

### FR-11: Modernizer Agent - Modernization Strategy
**Description**: Modernizer creates modernization plans
**Implementation**: `.github/agents/modernizer.agent.md` + `.github/prompts/modernize.prompt.md`
**Status**: ✅ Defined

**Capabilities**:
- Legacy system analysis
- Technical debt identification
- Modernization strategy
- Task generation for updates

---

## Acceptance Criteria

### AC-1: Agent Definitions
✅ **PASS**: All agents defined in `.github/agents/`
✅ **PASS**: Agents have clear roles and tools
✅ **PASS**: Agents reference appropriate prompts

### AC-2: Prompt Templates
✅ **PASS**: All workflow prompts exist in `.github/prompts/`
✅ **PASS**: Prompts provide clear instructions
✅ **PASS**: Prompts reference appropriate agents

### AC-3: APM Integration
✅ **PASS**: apm.yml configured
✅ **PASS**: APM scripts defined for workflows
✅ **PASS**: Azure standards package included
✅ **PASS**: APM CLI installed in dev container

### AC-4: Documentation Structure
✅ **PASS**: specs/ directory structure defined
❌ **FAIL**: No existing PRD (expected for new projects)
❌ **FAIL**: No existing FRDs (expected for new projects)
❌ **FAIL**: No existing task files (expected for new projects)

### AC-5: Infrastructure Templates
✅ **PASS**: Bicep templates exist
✅ **PASS**: Azure Verified Modules used
✅ **PASS**: azd configuration present
❌ **FAIL**: GitHub Actions workflows missing

### AC-6: MCP Integration
✅ **PASS**: MCP servers configured in `.vscode/mcp.json`
✅ **PASS**: context7, github, microsoft.docs, deepwiki available
✅ **PASS**: Agents have access to MCP tools

---

## Dependencies

### Internal Dependencies
- **GitHub Copilot**: Core AI agent platform
- **APM CLI**: Standards management
- **Azure Developer CLI**: Deployment orchestration
- **Dev Container**: Consistent environment

### External Dependencies
- **GitHub**: Repository and issue management
- **Azure**: Cloud infrastructure
- **MCP Servers**: External documentation and tooling

---

## Technical Implementation Details

### Agent Configuration

**Example: Dev Agent** (`.github/agents/dev.agent.md`)
```yaml
---
description: Breaks down features into tasks, implements code, or delegates
tools: ['runCommands', 'edit', 'search', 'new', 'context7/*', 'github/*', ...]
model: Claude Sonnet 4.5
name: dev
---
```

**Key Components**:
- **description**: Agent purpose
- **tools**: Available capabilities
- **model**: AI model used
- **name**: Agent identifier

---

### APM Configuration

**File**: `apm.yml`
```yaml
dependencies:
  apm:
    - danielmeppiel/azure-standards@1.0.0

scripts:
  prd: "copilot --allow-tool -p .github/prompts/prd.prompt.md"
  frd: "copilot --allow-tool -p .github/prompts/frd.prompt.md"
  plan: "copilot --allow-tool -p .github/prompts/plan.prompt.md"
  implement: "copilot --allow-tool -p .github/prompts/implement.prompt.md"
  delegate: "copilot --allow-tool -p .github/prompts/delegate.prompt.md"
  deploy: "copilot --allow-tool -p .github/prompts/deploy.prompt.md"
```

**Usage**:
```bash
apm run prd    # Start PRD workflow
apm run frd    # Start FRD workflow
apm run plan   # Start planning workflow
# ... etc
```

---

### MCP Server Configuration

**File**: `.vscode/mcp.json`
```json
{
  "servers": {
    "context7": { "type": "http", "url": "https://mcp.context7.com/mcp" },
    "github": { "type": "http", "url": "https://api.githubcopilot.com/mcp/" },
    "microsoft.docs.mcp": { "type": "http", "url": "https://learn.microsoft.com/api/mcp" },
    "deepwiki": { "type": "http", "url": "https://mcp.deepwiki.com/sse" },
    "playwright": { "type": "stdio", "command": "npx", "args": ["@playwright/mcp@latest"] }
  }
}
```

**Benefits**:
- Agents can access up-to-date documentation
- GitHub operations automated
- Browser automation for testing

---

## Workflow State Management

### Current State
**Location**: File system (`specs/` directory)
**Format**: Markdown files
**Versioning**: Git

### State Transitions

```
1. Idea (verbal/email)
   ↓ /prd
2. specs/prd.md created
   ↓ /frd
3. specs/features/*.md created
   ↓ /generate-agents (optional)
4. AGENTS.md generated
   ↓ /plan
5. specs/tasks/*.md created
   ↓ /implement OR /delegate
6. src/ code created
   ↓ /deploy
7. infra/ Bicep created + Azure deployment
```

---

## Integration Points

### GitHub Integration
- **Copilot Agents**: All workflows run through Copilot
- **Issues**: Delegation creates GitHub Issues
- **Pull Requests**: Copilot Coding Agent creates PRs
- **Actions**: Deployment workflows (when implemented)

### Azure Integration
- **Azure CLI**: Authentication and operations
- **Azure Developer CLI**: Deployment orchestration
- **Bicep**: Infrastructure definition
- **Container Apps**: Application hosting

### MCP Integration
- **Documentation Lookup**: context7, microsoft.docs
- **GitHub Operations**: github MCP server
- **Repository Understanding**: deepwiki
- **Browser Automation**: playwright

---

## Performance Characteristics

### Workflow Duration (Estimated)

| Workflow | Duration | Notes |
|----------|----------|-------|
| /prd | 10-30 min | Depends on product complexity and iterations |
| /frd | 5-15 min | Automated analysis of PRD |
| /generate-agents | 1-2 min | APM package download and compilation |
| /plan | 10-20 min | Depends on number of features |
| /implement | 30-120 min | Varies widely by feature complexity |
| /delegate | 5-10 min | Issue creation, then async Copilot work |
| /deploy | 10-30 min | Azure provisioning and deployment |

**Total End-to-End**: 1-4 hours for simple apps (vs days/weeks traditional)

---

## Security Considerations

### Access Control
- **GitHub PATs**: Required for MCP and APM access
- **Azure Credentials**: az login for local, managed identity for prod
- **Secrets**: No secrets in generated code (uses env vars)

### Code Review
- **Dev Lead Agent**: Reviews architecture and patterns
- **Human Review**: Still required for production code
- **PR Process**: Delegated implementations create PRs for review

---

## Scalability

### Team Scalability
- **Single Developer**: Full workflow automation
- **Small Team**: Divide workflows among team members
- **Large Team**: Multiple devs using `/implement`, coordinated by lead

### Project Scalability
- **Simple Apps**: Complete workflow in hours
- **Complex Apps**: Iterative application of workflows
- **Enterprise**: Multiple spec2cloud projects, shared standards

---

## Extensibility

### Custom Agents
- Add new `.agent.md` files in `.github/agents/`
- Define tools and model
- Create corresponding prompts

### Custom Standards
- Create APM packages with engineering rules
- Add to `apm.yml` dependencies
- Run `apm compile` to regenerate AGENTS.md

### Custom Workflows
- Add new prompts in `.github/prompts/`
- Add scripts to `apm.yml`
- Invoke with `apm run <script>`

---

## Testing Requirements

### Workflow Testing (Not Implemented)
**Needed**:
- Test each workflow end-to-end
- Validate generated artifacts
- Ensure agent handoffs work
- Verify deployment succeeds

### Integration Testing
**Needed**:
- MCP server connectivity
- GitHub API integration
- Azure CLI operations
- APM package management

---

## Known Issues and Limitations

### Functional Limitations
1. **No Workflow State Tracking**: No visual dashboard showing progress
2. **Manual Workflow Execution**: User must run each step manually
3. **No Rollback**: Cannot easily undo workflow steps
4. **Limited Validation**: No automated validation of generated artifacts
5. **No Workflow Branching**: Linear workflow only

### Technical Limitations
6. **Dependency on External Services**: GitHub, Azure, MCP servers must be available
7. **No Offline Mode**: All workflows require internet
8. **GitHub PAT Required**: Cannot use without GitHub token
9. **Azure Subscription Required**: Cannot deploy without Azure
10. **No Cost Estimation**: No automated cost projection for Azure resources

### Usability Limitations
11. **Command-Line Only**: No GUI for workflows
12. **Limited Error Recovery**: Failures require manual intervention
13. **No Progress Indicators**: Unclear how long workflows will take
14. **No Undo**: Cannot easily revert generated code/infra

---

## Implementation Status Summary

| Component | Status | Notes |
|-----------|--------|-------|
| PM Agent | ✅ Defined | Ready to use |
| Dev Lead Agent | ✅ Defined | Ready to use |
| Dev Agent | ✅ Defined | Ready to use |
| Azure Agent | ✅ Defined | Ready to use |
| Tech Analyst Agent | ✅ Defined | Used for this analysis |
| Modernizer Agent | ✅ Defined | Ready to use |
| Planner Agent | ✅ Defined | Alternative to Dev for planning |
| APM Integration | ✅ Implemented | Working in dev container |
| MCP Servers | ✅ Configured | All servers accessible |
| PRD Workflow | ✅ Ready | Prompt exists, not tested |
| FRD Workflow | ✅ Ready | Prompt exists, not tested |
| Plan Workflow | ✅ Ready | Prompt exists, not tested |
| Implement Workflow | ✅ Ready | Prompt exists, not tested |
| Delegate Workflow | ✅ Ready | Prompt exists, not tested |
| Deploy Workflow | ✅ Demonstrated | Working infrastructure |
| CI/CD Workflows | ❌ Missing | GitHub Actions not generated |
| Workflow Dashboard | ❌ Not Implemented | No visual tracking |
| State Management | ⚠️ Basic | File-based only |

---

## Conclusion

Spec2Cloud is a **comprehensive, well-designed development workflow** that leverages AI agents to automate the software development lifecycle. 

**Strengths**:
- Clear role separation for agents
- Comprehensive prompts and documentation
- APM integration for standards management
- MCP integration for external capabilities
- Demonstrated with working infrastructure

**Weaknesses**:
- Not battle-tested (no evidence of multiple uses)
- Missing CI/CD workflows
- No visual workflow tracking
- Limited error recovery

**Production Readiness**: **60%** - Core workflows defined and ready, but missing CI/CD, monitoring, and validation features for enterprise use.

**Recommendation**: This is an **excellent starting point** for AI-powered development but requires additional tooling for production team use (dashboard, state management, validation).
