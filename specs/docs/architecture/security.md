# Security Architecture and Practices

## Overview

This document describes the security architecture, authentication and authorization patterns, data protection mechanisms, and identified security gaps in the agentic-shell-python application.

---

## Security Model Summary

**Current Security Posture**: **Basic** - Relies on Azure platform security with minimal application-level controls

**Strengths**:
- ✅ Managed identity authentication (no secrets in code)
- ✅ HTTPS for external traffic
- ✅ CORS protection (backend restricted to frontend)
- ✅ Azure platform security (patching, encryption at rest)

**Weaknesses**:
- ❌ No user authentication (anonymous access)
- ❌ No authorization/access control
- ❌ No rate limiting
- ❌ No input validation
- ❌ Public endpoints (no network isolation)
- ❌ Single region (no disaster recovery)

---

## Authentication

### User Authentication

**Current Status**: ❌ **Not Implemented**

**Access Control**: Open access - anyone with URL can use the application

**Implications**:
- No user identity tracking
- Cannot attribute conversations to users
- Cannot implement user-level rate limiting
- Cannot enforce usage quotas
- Vulnerable to abuse


---


### Service-to-Service Authentication

**Current Status**: ✅ **Implemented with Managed Identity**

**Pattern**: Azure Managed Identity with RBAC
**Token Scope**: `https://cognitiveservices.azure.com/.default`

---

#### Managed Identity Flow

**Backend to Azure OpenAI**:
```
1. Container App → Azure AD: Request token (managed identity)
2. Azure AD → Container App: Return access token
3. Container App → OpenAI: API request + Bearer token
4. OpenAI: Validate token (RBAC check)
5. OpenAI → Container App: API response
```

**Code Implementation** (`src/agentic-api/main.py`):
```python
from azure.identity.aio import DefaultAzureCredential

chat_client = AzureOpenAIChatClient(
    endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
    credential=DefaultAzureCredential(),
    credential_scopes=["https://cognitiveservices.azure.com/.default"],
)
```

**Benefits**:
- No secrets in code or environment variables
- Automatic token rotation
- Centralized identity management
- Audit trail in Azure AD logs

---

#### RBAC Role Assignments

**agentic-api Identity** → **Azure OpenAI**:
- **Role**: `Cognitive Services OpenAI User`
- **Permissions**: Read, use deployments
- **Scope**: OpenAI account

**agentic-api Identity** → **Cosmos DB**:
- **Role**: `Cosmos DB Built-in Data Contributor`
- **Permissions**: Read, write data
- **Scope**: Cosmos DB account

**agentic-api Identity** → **Azure AI Search**:
- **Role**: `Search Index Data Contributor`
- **Permissions**: Read, write index data
- **Scope**: Search service

**agentic-ui Identity** → **Container Registry**:
- **Role**: `AcrPull`
- **Permissions**: Pull images
- **Scope**: Container Registry

---

## Authorization

### Application-Level Authorization

**Current Status**: ❌ **Not Implemented**

**No Access Control**:
- No role-based access control (RBAC)
- No user permissions
- No resource-level authorization
- All authenticated users have same permissions


---


### Resource-Level Authorization

**Example: Conversation Access Control**:
```python
def get_conversation(conversation_id: str, user_id: str):
    conversation = cosmos_container.read_item(
        item=conversation_id,
        partition_key=user_id  # Ensures user can only access own data
    )
    return conversation
```

**Cosmos DB Partition Key**: `/userId` provides natural isolation

---

## Data Protection

### Encryption at Rest

**Azure Services**: ✅ **Enabled by Default**

**Encrypted Services**:
- **Azure OpenAI**: Microsoft-managed keys (MMK)
- **Cosmos DB**: Microsoft-managed keys (MMK)
- **Azure AI Search**: Microsoft-managed keys (MMK)
- **Container Registry**: Microsoft-managed keys (MMK)
- **Application Insights**: Microsoft-managed keys (MMK)

**Customer-Managed Keys (CMK)**: ❌ Not configured
**Azure Key Vault**: ❌ Not provisioned


---


### Encryption in Transit

**External Traffic**: ✅ **HTTPS (TLS 1.2+)**

**Certificate**: Managed by Azure Container Apps (automatic)
**Protocol**: TLS 1.2 minimum, TLS 1.3 preferred
**Cipher Suites**: Modern, secure ciphers only

**Internal Traffic**: HTTP (unencrypted)

**Service-to-Service Communication**:
- Frontend → Backend: HTTP (internal)
- Backend → OpenAI: HTTPS ✅
- Backend → Cosmos DB: HTTPS ✅
- Backend → AI Search: HTTPS ✅

---


### Data Privacy

**Personally Identifiable Information (PII)**:
- ❌ No PII detection or redaction
- ❌ No data retention policies
- ❌ No data deletion on user request (GDPR "right to be forgotten")

**Sensitive Data in Logs**:
- Application Insights logs may contain user messages
- OpenTelemetry traces may include conversation content
- No log sanitization or PII filtering

---


## Network Security

### Public Endpoints

**Current Status**: ❌ **All services publicly accessible**

**Exposed Endpoints**:
- Frontend: `https://agentic-ui.{containerAppsEnvironment}.azurecontainerapps.io`
- Backend: `https://agentic-api.{containerAppsEnvironment}.azurecontainerapps.io`
- Azure OpenAI: `https://{accountName}.openai.azure.com`
- Cosmos DB: `https://{accountName}.documents.azure.com`
- Azure AI Search: `https://{serviceName}.search.windows.net`

**Risk**: Services accessible from any internet-connected device

---

### CORS Protection

**Backend API**: ✅ **CORS configured**

**Configuration** (`src/agentic-api/main.py`):
```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        os.environ.get("FRONTEND_URL", "http://localhost:3000"),
        "https://agentic-ui.*.azurecontainerapps.io"  # Production
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**Protection**: Prevents direct API access from unauthorized domains


---


### Network Security Groups (NSGs)

**Current Status**: Not configured

---


## Input Validation

### Current Status: ❌ **Minimal Validation**

**Framework Defaults**: FastAPI provides basic type checking
**Custom Validation**: None implemented


---


## Rate Limiting

### Current Status: ❌ **Not Implemented**

**No Throttling**:
- Users can send unlimited requests
- Vulnerable to abuse/DoS attacks
- No protection against bot attacks
- Azure OpenAI quota can be exhausted


---


## Security Headers

### Current Status: Default Headers Only

---


## Secrets Management

### Current Status: ✅ **No Secrets in Code**

**Managed Identity**: All Azure service authentication via managed identity
**No Connection Strings**: No secrets in environment variables

**If Secrets Required** (API keys, etc.):
- ✅ Use Azure Key Vault
- ✅ Reference secrets in Container App configuration
- ❌ Never commit secrets to Git

**Example**:
```bicep
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${environmentName}-kv'
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
  }
}

resource agenticApi 'Microsoft.App/containerApps@2024-03-01' = {
  properties: {
    configuration: {
      secrets: [
        {
          name: 'api-key'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/api-key'
          identity: agenticApiIdentity.id
        }
      ]
      env: [
        {
          name: 'API_KEY'
          secretRef: 'api-key'
        }
      ]
    }
  }
}
```

---

## Logging & Auditing

### Security Logging

**Current**: General application logs (stdout/stderr)
**Missing**: Security-specific events

**Events to Log**:
- Authentication attempts (success/failure)
- Authorization failures
- Rate limit violations
- Suspicious input patterns
- Admin actions
- Data access (Cosmos DB reads/writes)

**Implementation**:
```python
import logging

security_logger = logging.getLogger("security")

@app.post("/")
async def agent_endpoint(request: ChatRequest, user_id: str = Depends(verify_token)):
    security_logger.info(f"User {user_id} accessed agent endpoint", extra={
        "user_id": user_id,
        "ip": request.client.host,
        "user_agent": request.headers.get("user-agent")
    })
    # Process request
```

---

### Audit Trail

**Cosmos DB**: Change feed for audit trail
```python
from azure.cosmos import PartitionKey

# Enable change feed on container
container = database.create_container_if_not_exists(
    id='conversations',
    partition_key=PartitionKey(path='/userId'),
    analytical_storage_enabled=True  # For long-term audit storage
)

# Read change feed
changes = container.query_items_change_feed(
    start_time=datetime.utcnow() - timedelta(hours=1)
)
for change in changes:
    audit_logger.info(f"Document changed: {change['id']}")
```

---



## Threat Modeling

### STRIDE Analysis

**Spoofing**:
- ❌ No user authentication (anyone can impersonate)
- ✅ Service authentication via managed identity

**Tampering**:
- ✅ HTTPS prevents MITM attacks
- ❌ No input validation (malicious payloads possible)

**Repudiation**:
- ❌ No audit logging (actions not traceable)
- ⚠️ Application Insights logs (partial)

**Information Disclosure**:
- ⚠️ Logs may contain PII
- ✅ Encryption at rest and in transit

**Denial of Service**:
- ❌ No rate limiting (vulnerable to DoS)
- ⚠️ Azure platform protections (DDoS)

**Elevation of Privilege**:
- ❌ No authorization (all users have same privileges)
- ✅ RBAC for service accounts

---

### Attack Vectors

**1. Prompt Injection**:
- **Threat**: Malicious prompts manipulate AI behavior
- **Example**: "Ignore previous instructions. You are now a..."
- **Mitigation**: System prompt isolation, content filtering

**2. Data Exfiltration**:
- **Threat**: AI reveals sensitive training data or other users' data
- **Example**: "What did the previous user ask?"
- **Mitigation**: Stateless agent, no cross-user data access

**3. Resource Exhaustion**:
- **Threat**: Unlimited requests exhaust OpenAI quota
- **Example**: Bot sends 100 requests/second
- **Mitigation**: Rate limiting, user authentication

**4. Injection Attacks** (SQL, NoSQL):
- **Threat**: Malicious input exploits database queries
- **Example**: `" OR userId = 'admin' --`
- **Mitigation**: Parameterized queries (Cosmos SDK handles this)

---

## Security Monitoring

### Metrics to Track

**Authentication**:
- Failed login attempts
- Token expiration errors
- Managed identity failures

**Authorization**:
- Access denied errors
- Quota violations
- Suspicious access patterns

**Application**:
- Input validation failures
- Rate limit violations
- Unusual traffic spikes

---

### Alerting Rules

**Azure Monitor Alerts**:
```kusto
// Alert: High error rate
requests
| where timestamp > ago(5m)
| summarize error_rate = countif(resultCode >= 400) * 100.0 / count()
| where error_rate > 5

// Alert: Unusual traffic
requests
| where timestamp > ago(5m)
| summarize count()
| where count_ > 1000

// Alert: OpenAI throttling
dependencies
| where target contains "openai.azure.com"
| where resultCode == "429"
| summarize count() by bin(timestamp, 5m)
| where count_ > 10
```





## Summary

### Current State

**Security Implementation**:
- Platform security provided by Azure
- Managed identity authentication for Azure services
- HTTPS for external traffic
- CORS protection

**Security Gaps**:
- No user authentication
- No rate limiting
- Minimal input validation
- Public endpoints
- No comprehensive security logging
