targetScope = 'resourceGroup'

type AzureOpenAIResource = {
  resourceGroupName: string
  name: string
}

type AzureOpenAIResourceOutput = {
  resourceId: string
  resourceGroupName: string
  resourceName: string
  endpoint: string
}

param existingAoaiResource AzureOpenAIResource
param apimManagedIdentityPrincipalId string

var cognitiveServicesUserRoleDefinitionId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

resource aoaiResource 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: existingAoaiResource.name
}

resource aoaiRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    apimManagedIdentityPrincipalId,
    cognitiveServicesUserRoleDefinitionId,
    aoaiResource.id,
    resourceGroup().id
  )
  scope: aoaiResource
  properties: {
    principalId: apimManagedIdentityPrincipalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesUserRoleDefinitionId)
  }
}


output aoaiInformation AzureOpenAIResourceOutput = {
  resourceId: aoaiResource.id
  resourceName: aoaiResource.name
  resourceGroupName: resourceGroup().name
  endpoint: aoaiResource.properties.endpoint
}
