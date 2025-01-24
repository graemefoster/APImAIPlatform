targetScope = 'resourceGroup'
param aiFoundryManagedIdentityName string
param azopenaiName string
param azureaiFoundryUsersGroupObjectId string
param aiCentralName string
param appInsightsName string
param aiFoundryRg string

resource aiFoundryPrincipal 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  scope: resourceGroup(aiFoundryRg)
  name: aiFoundryManagedIdentityName
}

resource azOpenAI 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: azopenaiName
}

resource aiCentral 'Microsoft.Web/sites@2024-04-01' existing = {
  name: aiCentralName
}

resource contributor 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

//give Azure AI Studio appid (0736f41a-0425-4b46-bdb5-1563eff02385) access to backing services
//Not sure exactly what it needs.
// resource machineLearningAppReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid('${azureMachineLearningServicePrincipalId}-contributor-${resourceGroup().name}')
//   scope: resourceGroup()
//   properties: {
//     roleDefinitionId: contributor.id
//     principalId: azureMachineLearningServicePrincipalId
//     principalType: 'ServicePrincipal'
//   }
// }

resource aiFoundryNetworkApprover 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'b556d68e-0be0-4f35-a333-ad7ee1ce17ea'
}

resource uamiRoleAICentralAssignmentNetworkApprover 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentityName}-networkapprover-${aiCentralName}')
  scope: aiCentral
  properties: {
    roleDefinitionId: aiFoundryNetworkApprover.id
    principalId: aiFoundryPrincipal.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

//giving managed identity contributor on the rg
resource rgvContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentityName}-contributor-${resourceGroup().name}')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: contributor.id
    principalId: aiFoundryPrincipal.properties.principalId
    principalType: 'ServicePrincipal'
  }
}


// resource uamiRoleResourceGroupAssignmentNetworkApprover 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid('${aiFoundryManagedIdentityName}-networkapprover-${resourceGroup().name}')
//   scope: resourceGroup()
//   properties: {
//     roleDefinitionId: aiFoundryNetworkApprover.id
//     principalId: aiFoundryPrincipalId
//     principalType: 'ServicePrincipal'
//   }
// }

resource appInsightsContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentityName}-contributor-${appInsights.name}')
  scope: appInsights
  properties: {
    roleDefinitionId: contributor.id
    principalId: aiFoundryPrincipal.properties.principalId
    principalType: 'ServicePrincipal'
  }
}


//Allow AI Studio to PUT an embeddings model - it needs this to perform indexing
resource aoaiContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentityName}-contributor-${azOpenAI.name}')
  scope: azOpenAI
  properties: {
    roleDefinitionId: contributor.id
    principalId: aiFoundryPrincipal.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

//AI Studio uses the /ingestion endpoint which isn't covered in Cog Svc users. This is performed as the AI Studio user
resource aoaiContributorRole 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'a001fd3d-188f-4b5d-821b-7da978bf7442'
}

//and contributor on the overall workspace resource group
resource aoaiContributorRoleForaiFoundryGroup 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${azureaiFoundryUsersGroupObjectId}-aoaiContributor-${azOpenAI.name}')
  scope: azOpenAI
  properties: {
    roleDefinitionId: aoaiContributorRole.id
    principalId: azureaiFoundryUsersGroupObjectId
    principalType: 'Group'
  }
}

