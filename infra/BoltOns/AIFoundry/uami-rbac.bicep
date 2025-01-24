//taken from https://learn.microsoft.com/en-us/azure/machine-learning/how-to-identity-based-service-authentication?view=azureml-api-2&tabs=cli

param aiFoundryAzureSearch string
param aiFoundryStorage string
param aiFoundryKeyVault string
param aiFoundryAcr string
param aiFoundryManagedIdentityName string
param location string = resourceGroup().location

resource aiFoundryManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: aiFoundryManagedIdentityName
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: aiFoundryAcr
}

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: aiFoundryKeyVault
}

resource azureSearch 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: aiFoundryAzureSearch
}

resource stg 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: aiFoundryStorage
}

resource contributor 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource acrContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentity.name}-contributor-${acr.name}')
  scope: acr
  properties: {
    roleDefinitionId: contributor.id
    principalId: aiFoundryManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource kvContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentity.name}-contributor-${kv.name}')
  scope: kv
  properties: {
    roleDefinitionId: contributor.id
    principalId: aiFoundryManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource stgContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentity.name}-contributor-${stg.name}')
  scope: stg
  properties: {
    roleDefinitionId: contributor.id
    principalId: aiFoundryManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource kvAdministratorRole 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
}

resource kvAdministrator 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentity.name}-kvadmin-${kv.name}')
  scope: kv
  properties: {
    roleDefinitionId: kvAdministratorRole.id
    principalId: aiFoundryManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource stgBlobDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}


resource stgBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentity.name}-storageblobdatacontributor-${kv.name}')
  scope: stg
  properties: {
    roleDefinitionId: stgBlobDataContributorRole.id
    principalId: aiFoundryManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource searchIndexReader 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
}

resource aiSearchContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentity.name}-indexreader-${azureSearch.name}')
  scope: azureSearch
  properties: {
    roleDefinitionId: searchIndexReader.id
    principalId: aiFoundryManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

//This is a bit speculative... Had lots of issues with complaints on this role missing
//And it's not clear whether it should be applied to the backing resources, or to the hub itself.
//So I put it on the backing resources, as-well as the rg containing the hub.
resource aiFoundryNetworkApprover 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'b556d68e-0be0-4f35-a333-ad7ee1ce17ea'
}

resource uamiRoleAICentralAssignmentNetworkApprover 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentityName}-networkapprover-${resourceGroup().name}')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: aiFoundryNetworkApprover.id
    principalId: aiFoundryManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

//and contributor on the overall workspace resource group
resource rgvContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentity.name}-contributor-${resourceGroup().name}')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: contributor.id
    principalId: aiFoundryManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output aiFoundryManagedIdentityName string = aiFoundryManagedIdentity.name
