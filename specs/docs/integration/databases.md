# Database Schema and Data Models

## Overview

This document describes the database architecture, schemas, and data persistence patterns in the agentic-shell-python application.

---

## Current Database Usage

### Status: **Provisioned but Unused**

**Provisioned Database**: Azure Cosmos DB (Serverless, SQL API)
**Connection in Code**: **None** - No database SDK or connection logic implemented

---

## Provisioned Database

### Azure Cosmos DB Configuration

**Service**: Azure Cosmos DB
**API**: SQL (Core) API - NoSQL document database
**Tier**: Serverless
**Location**: Same as resource group (e.g., `eastus`)
**Account Name**: `{environmentName}-cosmos-account`

**Bicep Definition** (`infra/resources.bicep`, lines ~200-239):
```bicep
module cosmos 'br/public:avm/res/document-db/database-account:0.13.1' = {
  name: 'cosmos-db'
  scope: resourceGroup
  params: {
    name: cosmosAccountName
    locations: [{ locationName: location, failoverPriority: 0 }]
    serverVersion: '4.2'
    capabilitiesToAdd: [ 'EnableServerless' ]
    sqlDatabases: [{
      name: 'agentic-storage'
      containers: [{
        name: 'conversations'
        indexingPolicy: { automatic: true }
        partitionKeyPaths: [ '/userId' ]
      }]
    }]
    managedIdentities: { systemAssigned: true }
    roleAssignments: [
      {
        principalId: agenticApiIdentity.properties.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Cosmos DB Built-in Data Contributor'
      }
      // ... user principal assignments
    ]
  }
}
```

**Provisioned Components**:
- **Account**: `{environmentName}-cosmos-account`
- **Database**: `agentic-storage`
- **Container**: `conversations`
- **Partition Key**: `/userId`
- **Indexing**: Automatic (all properties indexed)

**Authentication**: Managed Identity (no connection strings)
**RBAC Role**: Cosmos DB Built-in Data Contributor (read/write access)

---

### Why Unused?

**No SDK Installed**: `pyproject.toml` doesn't include `azure-cosmos`
**No Connection Code**: `src/agentic-api/main.py` has no Cosmos client initialization
**No Environment Variable**: `AZURE_COSMOS_ENDPOINT` defined in Bicep but not consumed

**Hypothesis**: Infrastructure prepared for future chat history persistence, but feature not yet implemented.

---

## Database Schema Design

### Intended Schema: Conversations Container

**Container**: `conversations`
**Purpose**: Store chat conversation history
**Partition Key**: `/userId` (user identifier for data isolation)

---

#### Example Document Structure

**Conversation Document** (inferred design):
```json
{
  "id": "conv-123e4567-e89b-12d3-a456-426614174000",
  "userId": "user-abc123",
  "agentId": "my_agent",
  "title": "Discussion about Azure OpenAI",
  "messages": [
    {
      "id": "msg-001",
      "role": "user",
      "content": "What is Azure OpenAI?",
      "timestamp": "2024-01-15T10:30:00Z"
    },
    {
      "id": "msg-002",
      "role": "assistant",
      "content": "Azure OpenAI is a Microsoft Azure service...",
      "timestamp": "2024-01-15T10:30:03Z",
      "metadata": {
        "model": "gpt-5-mini",
        "tokens": 150
      }
    }
  ],
  "created": "2024-01-15T10:30:00Z",
  "updated": "2024-01-15T10:35:00Z",
  "status": "active",
  "metadata": {
    "source": "web-ui",
    "ip": "203.0.113.42"
  }
}
```

**Field Descriptions**:
- `id` (string, PK): Unique conversation identifier (UUID format)
- `userId` (string, partition key): User identifier for data isolation and partitioning
- `agentId` (string): Which agent handled this conversation
- `title` (string): Auto-generated or user-provided conversation title
- `messages` (array): Ordered list of messages in conversation
  - `id` (string): Message identifier
  - `role` (enum): `user`, `assistant`, `system`
  - `content` (string): Message text
  - `timestamp` (ISO 8601): Message creation time
  - `metadata` (object, optional): Model info, token count, etc.
- `created` (ISO 8601): Conversation creation timestamp
- `updated` (ISO 8601): Last update timestamp
- `status` (enum): `active`, `archived`, `deleted`
- `metadata` (object, optional): Additional context (source, IP, tags)

---

#### Partition Key Strategy

**Chosen Key**: `/userId`

**Rationale**:
- **Isolation**: Each user's conversations in separate logical partition
- **Query Efficiency**: Most queries filter by user ("show me my conversations")
- **Scalability**: High cardinality (one partition per user)

**Partition Key Properties**:
- **Cardinality**: High (thousands to millions of unique users)
- **Query Pattern**: Users query their own data (single-partition queries)
- **Storage**: Unlimited (Hierarchical Partition Keys not needed)
- **Hot Partition Risk**: Low (assuming balanced user activity)

**Alternative Designs Considered**:
- `/id`: Poor choice (every query cross-partition)
- `/agentId`: Low cardinality (only one agent in current app)
- `/{userId}/{conversationId}`: Hierarchical, but overkill for this scale

---

### Indexing Strategy

**Policy**: Automatic indexing (Cosmos DB default)

**Indexed Paths** (automatic):
- `/*` (all properties)
- `/userId/?` (partition key, automatically indexed)
- `/created/?`
- `/updated/?`
- `/messages/[]/timestamp/?`

**Query Performance**:
- ✅ Fast: Queries filtered by `userId` (single-partition)
- ✅ Fast: Range queries on `created`, `updated` (indexed)
- ⚠️ Slow: Full-text search on `messages[].content` (not optimized)

**Optimization Recommendations**:
1. **Include Paths**: Only index frequently queried fields
2. **Exclude Paths**: Exclude `/messages/[]/content/*` (large text fields)
3. **Composite Indexes**: Create composite index for `/userId + /created` (common query pattern)

**Example Custom Indexing Policy**:
```json
{
  "automatic": true,
  "indexingMode": "consistent",
  "includedPaths": [
    { "path": "/*" }
  ],
  "excludedPaths": [
    { "path": "/messages/[]/content/*" },
    { "path": "/messages/[]/metadata/*" }
  ],
  "compositeIndexes": [
    [
      { "path": "/userId", "order": "ascending" },
      { "path": "/created", "order": "descending" }
    ]
  ]
}
```

---

## Data Access Patterns

### Current: No Database Access

**State Management**: In-memory only (no persistence)
**Conversation History**: Lost on container restart
**Multi-Turn Conversations**: Not supported (no state storage)

---

### Intended Access Patterns

#### 1. Create Conversation

**Operation**: Insert new conversation document

**Python Code** (example):
```python
from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential
import uuid
from datetime import datetime

client = CosmosClient(
    url=os.environ["AZURE_COSMOS_ENDPOINT"],
    credential=DefaultAzureCredential()
)

database = client.get_database_client("agentic-storage")
container = database.get_container_client("conversations")

def create_conversation(user_id: str, agent_id: str) -> dict:
    conversation = {
        "id": str(uuid.uuid4()),
        "userId": user_id,
        "agentId": agent_id,
        "title": "New Conversation",
        "messages": [],
        "created": datetime.utcnow().isoformat() + "Z",
        "updated": datetime.utcnow().isoformat() + "Z",
        "status": "active"
    }
    container.create_item(body=conversation)
    return conversation
```

**RU Cost**: ~5-10 RUs per operation

---

#### 2. Append Message to Conversation

**Operation**: Update conversation, append message to array

**Python Code** (example):
```python
def add_message(conversation_id: str, user_id: str, role: str, content: str):
    # Read conversation
    conversation = container.read_item(
        item=conversation_id, 
        partition_key=user_id
    )
    
    # Append message
    message = {
        "id": str(uuid.uuid4()),
        "role": role,
        "content": content,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }
    conversation["messages"].append(message)
    conversation["updated"] = datetime.utcnow().isoformat() + "Z"
    
    # Update conversation
    container.replace_item(
        item=conversation_id,
        body=conversation
    )
```

**RU Cost**: 
- Read: ~1 RU per 1 KB
- Write: ~5 RUs per 1 KB

**Warning**: Large message arrays increase document size → higher RU costs and slower queries.

---

#### 3. List User's Conversations

**Operation**: Query conversations by userId

**Python Code** (example):
```python
def list_conversations(user_id: str, limit: int = 20):
    query = "SELECT * FROM c WHERE c.userId = @userId ORDER BY c.updated DESC OFFSET 0 LIMIT @limit"
    parameters = [
        {"name": "@userId", "value": user_id},
        {"name": "@limit", "value": limit}
    ]
    items = container.query_items(
        query=query,
        parameters=parameters,
        enable_cross_partition_query=False,  # Single partition query
        partition_key=user_id
    )
    return list(items)
```

**RU Cost**: ~2-5 RUs (single-partition query)

---

#### 4. Get Conversation by ID

**Operation**: Point read (most efficient)

**Python Code** (example):
```python
def get_conversation(conversation_id: str, user_id: str):
    conversation = container.read_item(
        item=conversation_id,
        partition_key=user_id
    )
    return conversation
```

**RU Cost**: ~1 RU (point read, most efficient operation)

---

#### 5. Delete Conversation

**Operation**: Soft delete (update status) or hard delete

**Python Code** (soft delete):
```python
def delete_conversation(conversation_id: str, user_id: str):
    conversation = container.read_item(
        item=conversation_id,
        partition_key=user_id
    )
    conversation["status"] = "deleted"
    conversation["updated"] = datetime.utcnow().isoformat() + "Z"
    container.replace_item(
        item=conversation_id,
        body=conversation
    )
```

**RU Cost**: Read (1 RU) + Write (5 RUs) = ~6 RUs total

---

## Data Models

### Conversation Model

**Entity**: Conversation
**Purpose**: Group related messages between user and agent

**Attributes**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique identifier (UUID) |
| `userId` | string | Yes | Partition key, user identifier |
| `agentId` | string | Yes | Agent that handled conversation |
| `title` | string | No | Conversation title |
| `messages` | array | Yes | List of messages (empty initially) |
| `created` | string | Yes | ISO 8601 timestamp |
| `updated` | string | Yes | ISO 8601 timestamp |
| `status` | enum | Yes | `active`, `archived`, `deleted` |
| `metadata` | object | No | Additional context |

**Size Estimate**:
- Base document: ~500 bytes
- Per message: ~200-1000 bytes (depending on content length)
- Max document size: 2 MB (Cosmos DB limit)
- Estimated max messages: ~1000-2000 per conversation

---

### Message Model

**Entity**: Message (embedded in Conversation)
**Purpose**: Single message in conversation

**Attributes**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique message identifier |
| `role` | enum | Yes | `user`, `assistant`, `system` |
| `content` | string | Yes | Message text |
| `timestamp` | string | Yes | ISO 8601 timestamp |
| `metadata` | object | No | Model, tokens, etc. |

**Constraints**:
- `role`: Must be one of `user`, `assistant`, `system`
- `content`: Max length ~8000 characters (model limit)
- `timestamp`: ISO 8601 format with timezone

---

## Data Persistence Strategy

### Current Strategy: None (In-Memory)

**State**: Ephemeral (lost on restart)
**Conversation Continuity**: Not supported
**Scalability**: Limited (memory-bound)


---




## Data Retention & Lifecycle

### Current: No Retention Policy

**Data Lifecycle**: N/A (no data stored)


---


## Data Security

### Authentication

**Method**: Managed Identity (Azure AD)
**No Secrets**: No connection strings in code
**RBAC Role**: `Cosmos DB Built-in Data Contributor`

**Bicep Configuration**:
```bicep
roleAssignments: [
  {
    principalId: agenticApiIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: 'Cosmos DB Built-in Data Contributor'
  }
]
```

---

### Data Isolation

**Partition Key**: `/userId` ensures user data isolation
**Row-Level Security**: Not natively supported; enforce in application code

**Application-Level Security**:
```python
def get_conversation(conversation_id: str, user_id: str):
    # Enforce user can only access their own data
    conversation = container.read_item(
        item=conversation_id,
        partition_key=user_id  # Must match user's ID
    )
    return conversation
```

---

### Encryption

**At Rest**: Automatic (Microsoft-managed keys)
**In Transit**: HTTPS (TLS 1.2+)
**Customer-Managed Keys**: Not configured (optional)

---

### Compliance

**Regions**: Single region (same as app)
**Data Residency**: Respects region choice
**GDPR**: Supports data deletion (right to be forgotten)

---

## Performance Optimization

### Request Units (RU) Optimization

**Serverless Tier**: Pay per request (RU/s)
**Cost**: $0.25 per 1 million RUs

**Optimization Strategies**:
1. **Point Reads**: Use `read_item()` instead of queries (1 RU vs 2-5 RUs)
2. **Single-Partition Queries**: Always filter by `userId` (avoids cross-partition)
3. **Projection**: Use `SELECT id, title` instead of `SELECT *`
4. **Caching**: Cache frequently accessed conversations in Redis/memory

---

### Query Performance

**Slow Query** (cross-partition):
```sql
SELECT * FROM c WHERE c.agentId = 'my_agent' ORDER BY c.created DESC
```
**Cost**: ~10-50 RUs (scans all partitions)

**Fast Query** (single-partition):
```sql
SELECT * FROM c WHERE c.userId = 'user-123' ORDER BY c.created DESC
```
**Cost**: ~2-5 RUs (single partition)

---

### Document Size Management

**Problem**: Large message arrays increase document size → higher costs

**Solutions**:
1. **Pagination**: Split large conversations into multiple documents
2. **Message Archive**: Move old messages to separate container
3. **Compression**: Store `content` as compressed JSON (not natively supported)

**Example Pagination Strategy**:
```json
{
  "id": "conv-123-page-1",
  "userId": "user-123",
  "conversationId": "conv-123",
  "pageNumber": 1,
  "messages": [/* first 100 messages */]
}
```

---

## Monitoring & Diagnostics

### Metrics to Monitor

**Request Metrics**:
- Total RU consumption per hour/day
- Average RU per operation type (read, write, query)
- Request rate (requests per second)

**Performance Metrics**:
- Query latency (P50, P95, P99)
- Throttling rate (429 errors)
- Availability (success rate)

**Data Metrics**:
- Total document count
- Total storage size
- Average document size

---

### Azure Monitor Queries

**Total RU Consumption** (KQL):
```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "DataPlaneRequests"
| summarize sum(todouble(requestCharge_s)) by bin(TimeGenerated, 1h)
```

**Slow Queries** (KQL):
```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "DataPlaneRequests"
| where todouble(duration_s) > 1000  // Over 1 second
| project TimeGenerated, activityId_g, duration_s, requestCharge_s
```

---

## Testing Strategy

### Current: No Database Tests


---




## Summary

### Current State
**Database**: Provisioned but unused
**Persistence**: None (in-memory only)
**Conversation History**: Not supported
