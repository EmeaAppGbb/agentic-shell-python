@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}


param agenticApiExists bool
param agenticUiExists bool
param aiFoundryProjectEndpoint string
param openAiEndpoint string
param deploymentName string

@description('Id of the user or app to assign application roles')
param principalId string

@description('Principal type of user or app')
param principalType string

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location)

// Monitor application with Azure Monitor
module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.0' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: '${abbrs.portalDashboards}${resourceToken}'
    location: location
    tags: tags
  }
}
// Container registry
module containerRegistry 'br/public:avm/res/container-registry/registry:0.1.1' = {
  name: 'registry'
  params: {
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
    publicNetworkAccess: 'Enabled'
    roleAssignments:[
      {
        principalId: agenticApiIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
      {
        principalId: agenticUiIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
    ]
  }
}

// Container apps environment
module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.4.5' = {
  name: 'container-apps-environment'
  params: {
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    zoneRedundant: false
  }
}
module cosmos 'br/public:avm/res/document-db/database-account:0.8.1' = {
  name: 'cosmos'
  params: {
    name: '${abbrs.documentDBDatabaseAccounts}${resourceToken}'
    tags: tags
    location: location
    locations: [
      {
        failoverPriority: 0
        isZoneRedundant: false
        locationName: location
      }
    ]
    networkRestrictions: {
      ipRules: []
      virtualNetworkRules: []
      publicNetworkAccess: 'Enabled'
    }
    sqlDatabases: [
      {
        name: 'agentic-storage'
        containers: [
        ]
      }
    ]
    sqlRoleAssignmentsPrincipalIds: [
      agenticApiIdentity.outputs.principalId
      agenticUiIdentity.outputs.principalId
      principalId
    ]
    sqlRoleDefinitions: [
      {
        name: 'service-access-cosmos-sql-role'
      }
    ]
    capabilitiesToAdd: [ 'EnableServerless' ]
  }
}
module search 'br/public:avm/res/search/search-service:0.10.0' = {
  name: 'ai-search'
  params: {
    name: '${abbrs.searchSearchServices}${resourceToken}'
    location: location
    tags: tags
    sku: 'basic'
    replicaCount: 1
    managedIdentities: {
      systemAssigned: true
    }
    roleAssignments: concat(
      principalType == 'User' ? [
        {  
          principalId: principalId
          principalType: 'User'
          roleDefinitionIdOrName: 'Search Index Data Contributor'  
        }
        {  
          principalId: principalId
          principalType: 'User'
          roleDefinitionIdOrName: 'Search Service Contributor'  
        }
      ] : [],
      [
        {
          principalId: agenticApiIdentity.outputs.principalId
          principalType: 'ServicePrincipal'
          roleDefinitionIdOrName: 'Search Index Data Contributor'
        }
        {
          principalId: agenticApiIdentity.outputs.principalId
          principalType: 'ServicePrincipal'
          roleDefinitionIdOrName: 'Search Service Contributor'
        }
        {
          principalId: agenticUiIdentity.outputs.principalId
          principalType: 'ServicePrincipal'
          roleDefinitionIdOrName: 'Search Index Data Contributor'
        }
        {
          principalId: agenticUiIdentity.outputs.principalId
          principalType: 'ServicePrincipal'
          roleDefinitionIdOrName: 'Search Service Contributor'
        }
      ]
    )
    disableLocalAuth: false
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    publicNetworkAccess: 'Enabled'
  }
}

module agenticApiIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'agenticApiidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}agenticApi-${resourceToken}'
    location: location
  }
}
module agenticApiFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'agenticApi-fetch-image'
  params: {
    exists: agenticApiExists
    name: 'agentic-api'
  }
}

module agenticApi 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'agenticApi'
  params: {
    name: 'agentic-api'
    ingressTargetPort: 8080
    corsPolicy: {
      allowedOrigins: [
        'https://agentic-ui.${containerAppsEnvironment.outputs.defaultDomain}'
      ]
      allowedMethods: [
        '*'
      ]
    }
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  [
      ]
    }
    containers: [
      {
        image: agenticApiFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: [
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: agenticApiIdentity.outputs.clientId
          }
          {
            name: 'AZURE_COSMOS_ENDPOINT'
            value: cosmos.outputs.endpoint
          }
          {
            name: 'AZURE_AI_SEARCH_ENDPOINT'
            value: search.outputs.endpoint
          }
          {
            name: 'AZURE_AI_PROJECT_ENDPOINT'
            value: aiFoundryProjectEndpoint
          }
          {
            name:'AZURE_OPENAI_ENDPOINT'
            value: openAiEndpoint
          }
          {
            name:'AZURE_OPENAI_DEPLOYMENT_NAME'
            value: deploymentName
          }
          {
            name: 'PORT'
            value: '8080'
          }
        ]
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [agenticApiIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: agenticApiIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'agentic-api' })
  }
}

resource agenticApibackendRoleAzureAIDeveloperRG 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, resourceGroup().id, agenticApiIdentity.name, '64702f94-c441-49e6-a78b-ef80e0188fee')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '64702f94-c441-49e6-a78b-ef80e0188fee') 
    principalId: agenticApiIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

resource agenticApibackendRoleCognitiveServicesUserRG 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, resourceGroup().id, agenticApiIdentity.name, 'a97b65f3-24c7-4388-baec-2e87135dc908')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908') 
    principalId: agenticApiIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

module agenticUiIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'agenticUiidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}agenticUi-${resourceToken}'
    location: location
  }
}
module agenticUiFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'agenticUi-fetch-image'
  params: {
    exists: agenticUiExists
    name: 'agentic-ui'
  }
}

module agenticUi 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'agenticUi'
  params: {
    name: 'agentic-ui'
    ingressTargetPort: 3000
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  [
      ]
    }
    containers: [
      {
        image: agenticUiFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: [
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: agenticUiIdentity.outputs.clientId
          }
          {
            name: 'AGENT_API_URL'
            value: 'https://agentic-api.${containerAppsEnvironment.outputs.defaultDomain}'
          }
          {
            name: 'PORT'
            value: '3000'
          }
        ]
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [agenticUiIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: agenticUiIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'agentic-ui' })
  }
}
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_RESOURCE_AGENTIC_API_ID string = agenticApi.outputs.resourceId
output AZURE_RESOURCE_AGENTIC_UI_ID string = agenticUi.outputs.resourceId
output AZURE_RESOURCE_AGENTIC_STORAGE_ID string = '${cosmos.outputs.resourceId}/sqlDatabases/agentic-storage'
output AZURE_AI_SEARCH_ENDPOINT string = search.outputs.endpoint
output AZURE_RESOURCE_SEARCH_ID string = search.outputs.resourceId
output aiSearchName string = search.outputs.name
