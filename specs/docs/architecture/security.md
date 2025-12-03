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

#### Recommended Implementation: Azure AD B2C

**Benefits**:
- Supports social logins (Google, Microsoft, GitHub)
- Email/password registration
- Multi-factor authentication (MFA)
- Identity federation
- Managed service (no custom auth code)

**Integration** (Next.js frontend):
```typescript
// src/agentic-ui/app/layout.tsx
import { SessionProvider } from "next-auth/react"
import { authOptions } from "./api/auth/[...nextauth]/route"

export default function RootLayout({ children }) {
  return (
    <SessionProvider>
      <CopilotKit runtimeUrl="/api/copilotkit">
        {children}
      </CopilotKit>
    </SessionProvider>
  )
}
```

**Protected Route**:
```typescript
// src/agentic-ui/app/page.tsx
import { useSession } from "next-auth/react"

export default function Home() {
  const { data: session, status } = useSession()
  
  if (status === "loading") return <div>Loading...</div>
  if (!session) return <div>Please sign in</div>
  
  return <CopilotSidebar />
}
```

**Backend Authentication** (FastAPI):
```python
# src/agentic-api/main.py
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

security = HTTPBearer()

async def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    # Verify JWT token from Azure AD B2C
    # Return user_id if valid, raise HTTPException if invalid
    pass

@app.post("/")
async def agent_endpoint(user_id: str = Depends(verify_token)):
    # user_id now available for all requests
    pass
```

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

#### Recommended Implementation: Attribute-Based Access Control (ABAC)

**User Attributes**:
```json
{
  "user_id": "user-123",
  "email": "user@example.com",
  "roles": ["user"],
  "subscription_tier": "free",
  "max_requests_per_day": 100
}
```

**Authorization Policy**:
```python
# src/agentic-api/main.py
from functools import wraps

def check_quota(func):
    @wraps(func)
    async def wrapper(user_id: str = Depends(verify_token)):
        # Check user's daily quota
        usage = await get_user_usage(user_id)
        quota = await get_user_quota(user_id)
        
        if usage >= quota:
            raise HTTPException(status_code=429, detail="Daily quota exceeded")
        
        return await func(user_id)
    return wrapper

@app.post("/")
@check_quota
async def agent_endpoint(user_id: str = Depends(verify_token)):
    # Process request
    pass
```

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

#### Customer-Managed Keys (CMK)

**If Required** (compliance, regulatory):
```bicep
// infra/resources.bicep
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${environmentName}-kv'
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enabledForDiskEncryption: true
  }
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: cosmosAccountName
  properties: {
    // ...
    encryption: {
      keyVaultKeyUri: keyVault.properties.vaultUri
    }
  }
}
```

**Cost**: Key Vault Standard ~$0.03/10k operations

---

### Encryption in Transit

**External Traffic**: ✅ **HTTPS (TLS 1.2+)**

**Certificate**: Managed by Azure Container Apps (automatic)
**Protocol**: TLS 1.2 minimum, TLS 1.3 preferred
**Cipher Suites**: Modern, secure ciphers only

**Internal Traffic**: ❌ **HTTP (unencrypted)**

**Service-to-Service Communication**:
- Frontend → Backend: HTTP (internal)
- Backend → OpenAI: HTTPS ✅
- Backend → Cosmos DB: HTTPS ✅
- Backend → AI Search: HTTPS ✅

**Recommendation**: Enable HTTPS for internal traffic
```bicep
resource agenticApi 'Microsoft.App/containerApps@2024-03-01' = {
  properties: {
    configuration: {
      ingress: {
        transport: 'https'  // Force HTTPS for internal traffic
      }
    }
  }
}
```

---

### Data Privacy

**Personally Identifiable Information (PII)**:
- ❌ No PII detection or redaction
- ❌ No data retention policies
- ❌ No data deletion on user request (GDPR "right to be forgotten")

**Sensitive Data in Logs**:
- ⚠️ Application Insights logs may contain user messages
- ⚠️ OpenTelemetry traces may include conversation content
- ❌ No log sanitization or PII filtering

**Recommendation**: Implement PII Detection
```python
import re

def sanitize_message(message: str) -> str:
    # Redact email addresses
    message = re.sub(r'\b[\w\.-]+@[\w\.-]+\.\w+\b', '[EMAIL]', message)
    # Redact phone numbers
    message = re.sub(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b', '[PHONE]', message)
    # Redact credit cards
    message = re.sub(r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b', '[CC]', message)
    return message

# Apply before logging
logger.info(f"User message: {sanitize_message(user_message)}")
```

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

### Private Endpoints (Recommended)

**Benefits**:
- Services accessible only from VNet
- No public internet exposure
- Reduced attack surface

**Implementation**:
```bicep
// infra/resources.bicep
resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: '${environmentName}-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      { name: 'container-apps', addressPrefix: '10.0.1.0/24' }
      { name: 'private-endpoints', addressPrefix: '10.0.2.0/24' }
    ]
  }
}

resource cosmosPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${environmentName}-cosmos-pe'
  location: location
  properties: {
    subnet: { id: vnet.properties.subnets[1].id }
    privateLinkServiceConnections: [{
      name: 'cosmos-connection'
      properties: {
        privateLinkServiceId: cosmosAccount.id
        groupIds: ['SQL']
      }
    }]
  }
}
```

**Cost**: ~$7/month per private endpoint

---

### Network Security Groups (NSGs)

**Current Status**: ❌ **Not configured**

**Recommendation**: Restrict inbound/outbound traffic
```bicep
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${environmentName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-https-inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'deny-all-inbound'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}
```

---

## Input Validation

### Current Status: ❌ **Minimal Validation**

**Framework Defaults**: FastAPI provides basic type checking
**Custom Validation**: None implemented

---

### Recommended Validation

**Message Length Limits**:
```python
from pydantic import BaseModel, Field

class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=5000)
    conversation_id: str | None = Field(None, regex=r'^[a-f0-9-]{36}$')

@app.post("/")
async def agent_endpoint(request: ChatRequest, user_id: str = Depends(verify_token)):
    # request.message automatically validated
    pass
```

**Content Filtering**:
```python
import re

BLOCKED_PATTERNS = [
    r'(?i)<script',  # XSS attempts
    r'(?i)javascript:',
    r'(?i)on\w+\s*=',  # Event handlers
]

def is_safe_content(message: str) -> bool:
    for pattern in BLOCKED_PATTERNS:
        if re.search(pattern, message):
            return False
    return True

@app.post("/")
async def agent_endpoint(request: ChatRequest, user_id: str = Depends(verify_token)):
    if not is_safe_content(request.message):
        raise HTTPException(status_code=400, detail="Invalid content detected")
    # Process request
```

---

### Azure AI Content Safety (Recommended)

**Service**: Azure AI Content Safety
**Purpose**: Detect harmful content (hate, violence, self-harm, sexual)

**Integration**:
```python
from azure.ai.contentsafety import ContentSafetyClient
from azure.core.credentials import AzureKeyCredential

content_safety_client = ContentSafetyClient(
    endpoint=os.environ["CONTENT_SAFETY_ENDPOINT"],
    credential=DefaultAzureCredential()
)

async def check_content_safety(text: str):
    result = content_safety_client.analyze_text(text=text)
    if result.severity > 2:  # Moderate or higher severity
        raise HTTPException(status_code=400, detail="Content violates safety policies")
```

**Cost**: $0.25 per 1000 text records

---

## Rate Limiting

### Current Status: ❌ **Not Implemented**

**No Throttling**:
- Users can send unlimited requests
- Vulnerable to abuse/DoS attacks
- No protection against bot attacks
- Azure OpenAI quota can be exhausted

---

### Recommended Implementation

**Option 1: Application-Level (Redis)**:
```python
from redis import Redis
from fastapi import HTTPException

redis_client = Redis(host='redis.example.com', port=6379, decode_responses=True)

async def rate_limit(user_id: str):
    key = f"rate_limit:{user_id}"
    count = redis_client.incr(key)
    
    if count == 1:
        redis_client.expire(key, 60)  # 1-minute window
    
    if count > 100:  # 100 requests per minute
        raise HTTPException(status_code=429, detail="Rate limit exceeded")

@app.post("/")
async def agent_endpoint(user_id: str = Depends(verify_token)):
    await rate_limit(user_id)
    # Process request
```

**Option 2: Azure API Management**:
- Deploy Azure APIM in front of backend
- Configure rate limiting policies
- Enforce quotas per user/API key
- **Cost**: ~$50/month (Consumption tier)

---

## Security Headers

### Current Status: ⚠️ **Default Headers Only**

**Recommended Headers**:
```python
# src/agentic-api/main.py
from fastapi.middleware.trustedhost import TrustedHostMiddleware

app.add_middleware(TrustedHostMiddleware, allowed_hosts=["*.azurecontainerapps.io"])

@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "default-src 'self'"
    return response
```

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

## Compliance

### GDPR (General Data Protection Regulation)

**Current Compliance**: ⚠️ **Partial**

**Requirements**:
- ✅ Data encryption at rest and in transit
- ❌ **Data subject access requests (DSAR)** - No implementation
- ❌ **Right to be forgotten** - No deletion mechanism
- ❌ **Data portability** - No export functionality
- ❌ **Privacy notice** - Not displayed to users
- ❌ **Consent management** - No consent tracking

**Implementation**:
```python
# DSAR: Export user data
@app.get("/api/users/{user_id}/data")
async def export_user_data(user_id: str = Depends(verify_token)):
    conversations = cosmos_container.query_items(
        query="SELECT * FROM c WHERE c.userId = @userId",
        parameters=[{"name": "@userId", "value": user_id}]
    )
    return {"user_id": user_id, "conversations": list(conversations)}

# Right to be forgotten: Delete user data
@app.delete("/api/users/{user_id}")
async def delete_user_data(user_id: str = Depends(verify_token)):
    # Delete all conversations
    conversations = cosmos_container.query_items(
        query="SELECT c.id FROM c WHERE c.userId = @userId",
        parameters=[{"name": "@userId", "value": user_id}]
    )
    for conv in conversations:
        cosmos_container.delete_item(item=conv['id'], partition_key=user_id)
    return {"status": "deleted"}
```

---

### HIPAA (Health Insurance Portability and Accountability Act)

**Current Compliance**: ❌ **Not compliant**

**If Required**:
- ✅ Azure services support HIPAA (with BAA)
- ❌ Encryption with customer-managed keys (CMK)
- ❌ Private endpoints (no public access)
- ❌ Audit logging (PHI access tracking)
- ❌ Business Associate Agreement (BAA) with Microsoft

---

### SOC 2 (Service Organization Control 2)

**Current Compliance**: ⚠️ **Partial (Azure platform)**

**Azure Services**: SOC 2 Type II certified
**Application**: No SOC 2 controls implemented

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

---

## Security Roadmap

### Phase 1: Critical (1-2 weeks)
1. ✅ **User Authentication**: Azure AD B2C
2. ✅ **Rate Limiting**: Application-level or APIM
3. ✅ **Input Validation**: Length limits, content filtering

### Phase 2: Important (2-4 weeks)
4. ✅ **Authorization**: RBAC/ABAC
5. ✅ **Security Logging**: Audit trail
6. ✅ **Network Security**: Private endpoints, NSGs

### Phase 3: Compliance (1-2 months)
7. ✅ **GDPR Compliance**: DSAR, right to be forgotten
8. ✅ **PII Detection**: Content sanitization
9. ✅ **Security Headers**: CSP, HSTS, etc.

### Phase 4: Advanced (2-3 months)
10. ✅ **WAF**: Azure Front Door or Application Gateway
11. ✅ **DDoS Protection**: Azure DDoS Protection Standard
12. ✅ **Penetration Testing**: Third-party security audit

---

## Security Best Practices

### Development
- Never commit secrets to Git
- Use `.env.local` for local secrets (gitignored)
- Rotate credentials regularly
- Use least-privilege access

### Deployment
- Enable managed identities for all services
- Use private endpoints in production
- Enable diagnostic logging
- Configure alerts for security events

### Operations
- Monitor security logs daily
- Review RBAC assignments quarterly
- Patch vulnerabilities promptly
- Conduct security reviews before major releases

---

## Conclusion

### Security Posture: **40/100**

**Current State**:
- Basic platform security (Azure)
- No application-level security controls
- Vulnerable to abuse and attacks

**Production Readiness**: **Not Ready**

### Critical Gaps (Must Fix Before Production)
1. ❌ User authentication
2. ❌ Rate limiting
3. ❌ Input validation
4. ❌ Security logging

### High-Priority Improvements
5. ❌ Authorization/RBAC
6. ❌ Private endpoints
7. ❌ Content filtering
8. ❌ GDPR compliance

### Recommended Next Steps
1. **Immediate**: Implement user authentication (Azure AD B2C)
2. **Week 1**: Add rate limiting and input validation
3. **Week 2**: Configure security logging and monitoring
4. **Month 1**: Deploy private endpoints and network security
5. **Month 2**: Conduct security audit and penetration testing

**Timeline to Production-Ready Security**: **2-3 months** with dedicated effort.
