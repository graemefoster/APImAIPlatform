targetScope = 'resourceGroup'

param location string
param aiStudioHubName string
param keyVaultName string
param storageName string
param acrName string
param azopenaiName string
param aiStudioProjectName string
param logAnalyticsId string

resource azOpenAI 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: azopenaiName
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: acrName
  location: location
  sku: { name: 'Premium' }
  properties: {
    adminUserEnabled: true
    anonymousPullEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageName
}

resource aiStudioManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: '${aiStudioProjectName}-uami'
  location: location
}

resource storageBlobDataWriter 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
}

resource uamiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiStudioManagedIdentity.name}-storagereader-${storage.name}')
  scope: storage
  properties: {
    roleDefinitionId: storageBlobDataWriter.id
    principalId: aiStudioManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource kvSecretsOfficer 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
}

resource uamiRoleAssignmentKv 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiStudioManagedIdentity.name}-kvsecretsofficer-${kv.name}')
  scope: kv
  properties: {
    roleDefinitionId: kvSecretsOfficer.id
    principalId: aiStudioManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource acrPullRole 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
}

resource acrPushRole 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: '8311e382-0749-4cb8-b61a-304f252e45ec'
}

resource uamiRoleAssignmentAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiStudioManagedIdentity.name}-acrpull-${acr.name}')
  scope: acr
  properties: {
    roleDefinitionId: acrPullRole.id
    principalId: aiStudioManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource aiStudioNetworkApprover 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'b556d68e-0be0-4f35-a333-ad7ee1ce17ea'
}


resource uamiRoleAssignmentNetworkApprover 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiStudioManagedIdentity.name}-networkapprover-${resourceGroup().name}')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: aiStudioNetworkApprover.id
    principalId: aiStudioManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource uamiRoleAssignmentAcrPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiStudioManagedIdentity.name}-acrpush-${acr.name}')
  scope: acr
  properties: {
    roleDefinitionId: acrPushRole.id
    principalId: aiStudioManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource aiStudioHub 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: aiStudioHubName
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aiStudioManagedIdentity.id}': {}
    }
  }
  kind: 'hub'
  properties: {
    allowPublicAccessWhenBehindVnet: true
    description: 'AI Studio project for the AI Ops Accelerator'
    friendlyName: aiStudioHubName
    keyVault: kv.id
    storageAccount: storage.id
    containerRegistry: acr.id
    primaryUserAssignedIdentity: aiStudioManagedIdentity.id
    publicNetworkAccess: 'Enabled'
    managedNetwork: {
      isolationMode: 'AllowInternetOutbound'
    }
  }

  resource aiServicesConnection 'connections@2024-04-01' = {
    name: 'aiServicesConnection'
    properties: {
      category: 'AzureOpenAI'
      target: azOpenAI.properties.endpoints['OpenAI Language Model Instance API']
      authType: 'ApiKey'
      isSharedToAll: true
      credentials: {
        key: azOpenAI.listKeys().key1
      }
      metadata: {
        ApiType: 'Azure'
        ResourceId: azOpenAI.id
      }
    }
  }
}

resource aoaiStudioProject 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: aiStudioProjectName
  location: resourceGroup().location
  kind: 'project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    allowPublicAccessWhenBehindVnet: true
    description: 'AI Studio project for the AI Ops Accelerator'
    friendlyName: aiStudioProjectName
    hubResourceId: aiStudioHub.id
    publicNetworkAccess: 'Enabled'
  }
}


resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: aiStudioHub
  name: 'diagnostics'
  properties: {
    workspaceId: logAnalyticsId
    logs: [
      {
        categoryGroup: 'AllLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
