targetScope = 'resourceGroup'

param aiSearchName string
param aiStudioManagedIdentityName string
param aiStudioManagedIdentityRg string
param azureAiStudioUsersGroupObjectId string

resource aiStudioManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: aiStudioManagedIdentityName
  scope: resourceGroup(aiStudioManagedIdentityRg)
}

resource aiSearch 'Microsoft.Search/searchServices@2024-03-01-Preview' existing = {
  name: aiSearchName
}

resource searchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
}

resource aiSearchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${azureAiStudioUsersGroupObjectId}-contributor-${aiSearch.name}')
  scope: aiSearch
  properties: {
    roleDefinitionId: searchServiceContributor.id
    principalId: azureAiStudioUsersGroupObjectId
    principalType: 'Group'
  }
}

resource searchIndexContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
}

resource aiSearchIndexContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${azureAiStudioUsersGroupObjectId}-indexContributor-${aiSearch.name}')
  scope: aiSearch
  properties: {
    roleDefinitionId: searchIndexContributor.id
    principalId: azureAiStudioUsersGroupObjectId
    principalType: 'Group'
  }
}


// For AI Studio PromptFlows - these should use the UAMI and need to query indexes
resource searchIndexReader 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
}

resource aiSearchContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiStudioManagedIdentity.name}-indexreader-${aiSearch.name}')
  scope: aiSearch
  properties: {
    roleDefinitionId: searchIndexReader.id
    principalId: aiStudioManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
