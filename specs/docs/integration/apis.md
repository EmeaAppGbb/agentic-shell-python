# API Documentation and Specifications

## Overview

This document describes all API endpoints, protocols, and integration interfaces exposed by the agentic-shell-python application.

---

## API Architecture

### API Pattern
**Type**: RPC-Style (Remote Procedure Call)
**Protocol**: HTTP POST with JSON payloads
**Framework**: AG-UI Protocol over FastAPI

**Not RESTful**: Single endpoint handles multiple operations, action-oriented rather than resource-oriented.

---

## Backend API

### Base Information
**Base URL (Production)**: `https://agentic-api.{containerAppsEnvironment.defaultDomain}`
**Base URL (Local)**: `http://localhost:8080`
**Protocol**: HTTP (internal), HTTPS (external)
**Content-Type**: `application/json`
**Authentication**: None (CORS-restricted to frontend)

---

### Endpoint: Root Agent Interaction

**URL**: `/`
**Method**: `POST`
**Purpose**: Send messages to AI agent and receive responses
**Protocol**: AG-UI (Microsoft Agent Framework Protocol)

**Implementation**: `src/agentic-api/main.py`
```python
add_agent_framework_fastapi_endpoint(app, agent, "/")
```

**Handler**: Agent Framework handles request marshalling

---

#### Request Format (Inferred)

**Headers**:
```http
POST / HTTP/1.1
Host: agentic-api.example.com
Content-Type: application/json
Accept: application/json
```

**Body** (AG-UI Protocol):
```json
{
  "message": "User message here",
  "conversation_id": "optional-uuid",
  "context": {
    "key": "value"
  },
  "agent": "my_agent",
  "stream": false
}
```

**Fields**:
- `message` (string, required): User's input message
- `conversation_id` (string, optional): For multi-turn conversations
- `context` (object, optional): Additional context
- `agent` (string, optional): Agent identifier (default: "my_agent")
- `stream` (boolean, optional): Whether to stream response (default: false)

**Note**: Exact schema depends on AG-UI protocol version; documentation not fully public.

---

#### Response Format (Inferred)

**Success Response (200 OK)**:
```json
{
  "response": "AI-generated response text",
  "conversation_id": "uuid-of-conversation",
  "metadata": {
    "model": "gpt-5-mini",
    "tokens_used": 150,
    "processing_time_ms": 2340
  }
}
```

**Fields**:
- `response` (string): AI-generated text response
- `conversation_id` (string): Conversation identifier
- `metadata` (object, optional): Additional information about the response

---

#### Error Responses

**400 Bad Request**:
```json
{
  "error": "Invalid request format",
  "details": "Missing required field: message"
}
```

**500 Internal Server Error**:
```json
{
  "error": "Internal server error",
  "details": "OpenAI API unavailable"
}
```

**503 Service Unavailable**:
```json
{
  "error": "Service unavailable",
  "details": "Azure OpenAI deployment not found"
}
```

---

#### Example Request/Response

**Request**:
```bash
curl -X POST https://agentic-api.example.com/ \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What is Azure OpenAI?",
    "agent": "my_agent"
  }'
```

**Response**:
```json
{
  "response": "Azure OpenAI is a Microsoft Azure service that provides access to OpenAI's powerful language models through a managed, enterprise-ready platform...",
  "conversation_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

---

### Authentication

**Current**: None
**CORS Protection**: Restricts requests to frontend origin only

---


### Rate Limiting

**Current**: Not implemented

**Existing Limits**:
- Azure OpenAI: Rate limited by Azure quota (TPM, RPM)
- Container Apps: No explicit throttling

---


## Frontend API (Next.js)

### Base Information
**Base URL (Production)**: `https://agentic-ui.{containerAppsEnvironment.defaultDomain}`
**Base URL (Local)**: `http://localhost:3000`
**Purpose**: Serve web UI and proxy agent requests

---

### Endpoint: CopilotKit Runtime

**URL**: `/api/copilotkit`
**Method**: `POST`
**Purpose**: Handle CopilotKit requests and route to backend agent
**Implementation**: `src/agentic-ui/app/api/copilotkit/route.ts`

**Type**: Backend for Frontend (BFF) pattern

---

#### Request Format

**Headers**:
```http
POST /api/copilotkit HTTP/1.1
Host: agentic-ui.example.com
Content-Type: application/json
Accept: application/json
```

**Body** (CopilotKit Protocol):
```json
{
  "message": "User message",
  "agentName": "my_agent",
  "threadId": "optional-thread-id",
  "properties": {}
}
```

**Note**: CopilotKit manages this protocol; frontend code doesn't directly call this endpoint.

---

#### Response Format

**Success (200 OK)**:
```json
{
  "response": "AI response",
  "threadId": "thread-uuid",
  "isComplete": true
}
```

**Error (4xx/5xx)**:
```json
{
  "error": "Error message",
  "code": "ERROR_CODE"
}
```

---

#### Backend Proxy Logic

**Implementation** (`src/agentic-ui/app/api/copilotkit/route.ts`):
```typescript
const runtime = new CopilotRuntime({
  agents: {
    my_agent: new HttpAgent({ 
      url: process.env.AGENT_API_URL 
    }),
  },
});

export const POST = async (req: NextRequest) => {
  const { handleRequest } = copilotRuntimeNextJSAppRouterEndpoint({
    runtime,
    serviceAdapter,
    endpoint: "/api/copilotkit",
  });
  return handleRequest(req);
};
```

**Flow**:
1. Receive POST from CopilotKit
2. Route to `my_agent` (HttpAgent)
3. HttpAgent forwards to `AGENT_API_URL` (backend)
4. Receive response from backend
5. Return response to CopilotKit

---

### Static Pages

**URL**: `/`
**Method**: `GET`
**Purpose**: Serve main application page

**Implementation**: `src/agentic-ui/app/page.tsx`
**Response**: HTML with embedded React application

---

## External API Integrations

### Azure OpenAI API

**Endpoint**: `{AZURE_OPENAI_ENDPOINT}`
**Example**: `https://ai-account-abc123.openai.azure.com/`
**Authentication**: Managed Identity (Azure AD token)

**SDK**: Azure SDK for Python (`AzureOpenAIChatClient`)

**Request** (via SDK):
```python
chat_client.chat(
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Hello"}
    ],
    deployment_name="gpt5MiniDeployment",
    temperature=0.7,
    max_tokens=800
)
```

**Response** (via SDK):
```python
{
    "id": "chatcmpl-...",
    "object": "chat.completion",
    "created": 1234567890,
    "model": "gpt-5-mini",
    "choices": [{
        "index": 0,
        "message": {
            "role": "assistant",
            "content": "Hello! How can I help you today?"
        },
        "finish_reason": "stop"
    }],
    "usage": {
        "prompt_tokens": 20,
        "completion_tokens": 10,
        "total_tokens": 30
    }
}
```

**API Documentation**: https://learn.microsoft.com/azure/ai-services/openai/reference

---

### Azure AI Foundry API

**Endpoint**: `{AZURE_AI_PROJECT_ENDPOINT}`
**Purpose**: Access AI Foundry project capabilities
**Status**: Provisioned but not actively used in visible code

**Potential Uses**:
- Prompt management
- Evaluation datasets
- Fine-tuning management

**API Documentation**: https://learn.microsoft.com/azure/ai-foundry/

---

### Azure Cosmos DB API (Not Used)

**Endpoint**: `{AZURE_COSMOS_ENDPOINT}`
**Status**: Provisioned but not connected in application code

**API**: SQL (Core) API
**SDK**: Likely `azure-cosmos` Python package (not installed)

**If Implemented**:
```python
from azure.cosmos import CosmosClient

client = CosmosClient(
    url=os.environ["AZURE_COSMOS_ENDPOINT"],
    credential=DefaultAzureCredential()
)

database = client.get_database_client("agentic-storage")
container = database.get_container_client("conversations")
```

**Use Case**: Persist chat history

---

### Azure AI Search API (Not Used)

**Endpoint**: `{AZURE_AI_SEARCH_ENDPOINT}`
**Status**: Provisioned but not connected in application code

**API**: Azure AI Search REST API
**SDK**: Likely `azure-search-documents` Python package (not installed)

**If Implemented**:
```python
from azure.search.documents import SearchClient
from azure.identity import DefaultAzureCredential

search_client = SearchClient(
    endpoint=os.environ["AZURE_AI_SEARCH_ENDPOINT"],
    index_name="documents",
    credential=DefaultAzureCredential()
)

results = search_client.search(search_text="query", top=5)
```

**Use Case**: RAG (Retrieval-Augmented Generation) for document search

---

## Protocol Specifications

### AG-UI Protocol

**Purpose**: Communication between CopilotKit UI and Microsoft Agent Framework

**Specification**: Not fully public; maintained by Microsoft
**Repository**: https://github.com/microsoft/ag-ui

**Key Concepts**:
- Agent-centric (not endpoint-centric)
- Supports multiple agents
- Handles conversation state
- Streaming support

---

### CopilotKit Protocol

**Purpose**: Communication between React components and CopilotRuntime

**Specification**: CopilotKit documentation
**Repository**: https://github.com/CopilotKit/CopilotKit

**Key Features**:
- React context-based
- Server actions
- Streaming responses
- Multi-agent support

---

## API Versioning

**Current**: No versioning
**URL Pattern**: No `/v1/` or version indicators

---


## API Documentation Generation

**Current Status**: No OpenAPI/Swagger specification

**FastAPI Built-in Docs**: Available at `/docs` and `/redoc` (if enabled)

---


## Request/Response Examples

### Example 1: Simple Chat

**Request**:
```json
POST / HTTP/1.1
Content-Type: application/json

{
  "message": "Hello, how are you?"
}
```

**Response**:
```json
HTTP/1.1 200 OK
Content-Type: application/json

{
  "response": "Hello! I'm doing well, thank you for asking. How can I assist you today?",
  "conversation_id": "conv-123"
}
```

---

### Example 2: Multi-Turn Conversation

**Request 1**:
```json
{
  "message": "What is machine learning?"
}
```

**Response 1**:
```json
{
  "response": "Machine learning is a branch of artificial intelligence...",
  "conversation_id": "conv-456"
}
```

**Request 2** (same conversation):
```json
{
  "message": "Can you give me an example?",
  "conversation_id": "conv-456"
}
```

**Response 2**:
```json
{
  "response": "Certainly! A common example of machine learning is email spam filtering...",
  "conversation_id": "conv-456"
}
```

---

### Example 3: Error Handling

**Request** (missing required field):
```json
{
  "agent": "my_agent"
}
```

**Response**:
```json
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "error": "Validation error",
  "details": "Missing required field: message"
}
```

---

## Performance Characteristics

### Latency
**Typical Response Time**: 1-5 seconds
**Breakdown**:
- Frontend → Backend: < 100ms
- Backend → OpenAI: 1-5 seconds (95% of latency)
- Backend → Frontend: < 100ms

### Throughput
**Expected**: 10-100 requests per minute per deployment
**Limited By**: Azure OpenAI quota (TPM, RPM)

### Concurrency
**Container Apps**: Up to 10 replicas, ~50 concurrent requests per replica
**OpenAI**: Shared rate limits across all requests

---

## Security Considerations

### Current Security
✅ **HTTPS**: External traffic encrypted
✅ **CORS**: Backend restricted to frontend origin
❌ **Authentication**: None (open access)
❌ **Authorization**: None
❌ **Rate Limiting**: None
❌ **Input Validation**: Minimal (framework defaults)

---


## Monitoring & Logging

### Application Insights Integration

**Automatic Tracking**:
- HTTP requests (method, status, duration)
- Dependencies (OpenAI API calls)
- Exceptions
- Custom events (if implemented)

**Query Example** (KQL):
```kusto
requests
| where timestamp > ago(1h)
| where url contains "agentic-api"
| summarize count(), avg(duration) by resultCode
```

---

## API Limitations

### Current Limitations
1. **No Streaming**: Responses delivered in full (not word-by-word)
2. **No Pagination**: Single response per request
3. **No Bulk Operations**: One message at a time
4. **No Webhooks**: No push notifications
5. **No File Uploads**: Text-only messages

### Size Limits
**Message Length**: No explicit limit (Azure OpenAI model limit: ~8k tokens for gpt-5-mini)
**Response Length**: Configured in `max_tokens` (likely default: 800)

---



## Testing APIs

### Current Status
**Unit Tests**: None
**Integration Tests**: None
**Load Tests**: None

---


## Summary

**Current API Implementation**:
- RPC-style design
- AG-UI protocol abstraction
- CORS security
- Monitoring integration

**Gaps**:
- No formal API documentation (OpenAPI)
- No authentication or authorization
- No rate limiting
- No API versioning
- Limited error handling
- No streaming responses
