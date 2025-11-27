targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@metadata({azd: {
  type: 'location'
  usageName: [
    'OpenAI.GlobalStandard.gpt-5-mini,10'
  ]}
})
param aiDeploymentsLocation string
param agenticApiExists bool
param agenticUiExists bool

@description('Id of the user or app to assign application roles')
param principalId string

@description('Principal type of user or app')
param principalType string

param deploymentName string = 'gpt5MiniDeployment'

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  scope: rg
  name: 'resources'
  params: {
    location: location
    tags: tags
    principalId: principalId
    principalType: principalType
    agenticApiExists: agenticApiExists
    agenticUiExists: agenticUiExists
    aiFoundryProjectEndpoint: aiModelsDeploy.outputs.ENDPOINT
    openAiEndpoint: aiModelsDeploy.outputs.OPENAI_ENDPOINT
    deploymentName: deploymentName
  }
}

module aiModelsDeploy 'ai-project.bicep' = {
  scope: rg
  name: 'ai-project'
  params: {
    tags: tags
    location: aiDeploymentsLocation
    envName: environmentName
    principalId: principalId
    principalType: principalType
    deployments: [
      {
        name: deploymentName
        model: {
          name: 'gpt-5-mini'
          format: 'OpenAI'
          version: '2025-08-07'
        }
        sku: {
          name: 'GlobalStandard'
          capacity: 10
        }
      }
    ]
  }
}
module aiSearchConnection 'modules/ai-search-conn.bicep' = {
  scope: rg
  name: 'ai-search-connection'
  params: {
    aiServicesName: aiModelsDeploy.outputs.aiServicesAccountName
    aiServicesProjectName: aiModelsDeploy.outputs.aiServicesProjectName
    aiSearchName: resources.outputs.aiSearchName
  }
}
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output AZURE_RESOURCE_AGENTIC_API_ID string = resources.outputs.AZURE_RESOURCE_AGENTIC_API_ID
output AZURE_RESOURCE_AGENTIC_UI_ID string = resources.outputs.AZURE_RESOURCE_AGENTIC_UI_ID
output AZURE_RESOURCE_AGENTIC_STORAGE_ID string = resources.outputs.AZURE_RESOURCE_AGENTIC_STORAGE_ID
output AZURE_AI_PROJECT_ENDPOINT string = aiModelsDeploy.outputs.ENDPOINT
output AZURE_RESOURCE_AI_PROJECT_ID string = aiModelsDeploy.outputs.projectId
output AZURE_AI_SEARCH_ENDPOINT string = resources.outputs.AZURE_AI_SEARCH_ENDPOINT
output AZURE_RESOURCE_SEARCH_ID string = resources.outputs.AZURE_RESOURCE_SEARCH_ID
output AZURE_OPENAI_ENDPOINT string = aiModelsDeploy.outputs.OPENAI_ENDPOINT
output AZURE_OPENAI_DEPLOYMENT_NAME string = deploymentName
