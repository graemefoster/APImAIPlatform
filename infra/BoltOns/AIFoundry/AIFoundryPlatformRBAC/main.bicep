targetScope = 'resourceGroup'
param aiFoundryManagedIdentityName string
param azopenaiName string
param aiCentralName string
param aiFoundryPrincipalId string
param azureaiFoundryUsersGroupObjectId string

resource aiCentral 'Microsoft.Web/sites@2023-12-01' existing = {
  name: aiCentralName
}

resource azOpenAI 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: azopenaiName
}

resource aiFoundryNetworkApprover 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'b556d68e-0be0-4f35-a333-ad7ee1ce17ea'
}

resource uamiRoleAICentralAssignmentNetworkApprover 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentityName}-networkapprover-${aiCentralName}')
  scope: aiCentral
  properties: {
    roleDefinitionId: aiFoundryNetworkApprover.id
    principalId: aiFoundryPrincipalId
    principalType: 'ServicePrincipal'
  }
}

//Allow AI Studio to PUT an embeddings model - it needs this to perform indexing
resource contributor 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource aoaiContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentityName}-contributor-${azOpenAI.name}')
  scope: azOpenAI
  properties: {
    roleDefinitionId: contributor.id
    principalId: aiFoundryPrincipalId
    principalType: 'ServicePrincipal'
  }
}

//AI Studio uses the /ingestion endpoint which isn't covered in Cog Svc users. This is performed as the AI Studio user
resource aoaiContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: 'a001fd3d-188f-4b5d-821b-7da978bf7442'
}

resource aoaiContributorRoleForaiFoundryGroup 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${azureaiFoundryUsersGroupObjectId}-aoaiContributor-${azOpenAI.name}')
  scope: azOpenAI
  properties: {
    roleDefinitionId: aoaiContributorRole.id
    principalId: azureaiFoundryUsersGroupObjectId
    principalType: 'Group'
  }
}


