targetScope = 'resourceGroup'

//This file is a bit of an experiementation into how AI Studio works. 
//I'm trying to build out prompt-flows / indexing / understand the security of everything

param location string
param aiStudioHubName string
param keyVaultName string
param storageName string
param acrName string
param azopenaiName string
param aiStudioProjectName string
param logAnalyticsId string
param aiCentralName string
param aiSearchRg string
param aiSearchName string

resource aiSearch 'Microsoft.Search/searchServices@2024-03-01-Preview' existing = {
  name: aiSearchName
  scope: resourceGroup(aiSearchRg)
}

resource aiCentral 'Microsoft.Web/sites@2023-12-01' existing = {
  name: aiCentralName
}

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

var aiStudioManagedIdentityName = '${aiStudioHubName}-uami'
resource aiStudioManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: aiStudioManagedIdentityName
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

//TODO - work out RG alignment. Not sure AI Studio should be in the platform RG. Maybe need for a third.
module aiSearchRbac 'aistudio-consumer-rbac.bicep' = {
  name: '${deployment().name}-aiSearchRbac'
  scope: resourceGroup(aiSearchRg)
  params: {
    aiSearchName: aiSearchName
    aiStudioManagedIdentityName: aiStudioManagedIdentityName
    aiStudioManagedIdentityRg: resourceGroup().name
  }
}

//Allow AI Studio to PUT an embeddings model - it needs this to perform indexing
resource contributor 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource aoaiContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiStudioManagedIdentity.name}-contributor-${azOpenAI.name}')
  scope: azOpenAI
  properties: {
    roleDefinitionId: contributor.id
    principalId: aiStudioManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

//when I try create compute I am told I need Contributor on the ACR, and the KV
resource kvContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiStudioManagedIdentity.name}-contributor-${kv.name}')
  scope: kv
  properties: {
    roleDefinitionId: contributor.id
    principalId: aiStudioManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource acrContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiStudioManagedIdentity.name}-contributor-${acr.name}')
  scope: acr
  properties: {
    roleDefinitionId: contributor.id
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
      outboundRules: {
        sampleapi: {
          type: 'PrivateEndpoint'
          category: 'UserDefined'
          destination: {
            serviceResourceId: aiCentral.id
            subresourceTarget: 'sites'
          }
        }
        //From what I can see, adding a AI Search connection doesn't auto create a private endpoint to AI Search. In contrast to adding an AOAI connection.
        aiSearch: {
          type: 'PrivateEndpoint'
          category: 'UserDefined'
          destination: {
            serviceResourceId: aiSearch.id
            subresourceTarget: 'searchService'
          }
        }
      }
    }
  }

  resource aiServicesConnection 'connections@2024-04-01' = {
    name: 'aiServicesConnection'
    properties: {
      category: 'AzureOpenAI'
      target: 'https://${aiCentral.properties.defaultHostName}' //  azOpenAI.properties.endpoint //needs deployment names exposed via AI Central to match ones in AOAI
      authType: 'AAD'
      isSharedToAll: true
      metadata: {
        ApiType: 'Azure'
        ResourceId: azOpenAI.id
      }
    }
  }

  resource aiSearchConnection 'connections@2024-04-01' = {
    name: 'aiSearchConnection'
    properties: {
      category: 'CognitiveSearch'
      target: 'https://${aiSearch.name}.search.windows.net'
      authType: 'AAD'
      isSharedToAll: true
      metadata: {
        ApiType: 'Azure'
        ResourceId: aiSearch.id
      }
    }
    dependsOn: [
      aiServicesConnection
    ]
  }
}

// struggle to recreate this. 
resource aoaiStudioProject 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: aiStudioProjectName
  location: resourceGroup().location
  kind: 'project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'AI Studio project for the AI Ops Accelerator'
    friendlyName: aiStudioProjectName
    hubResourceId: aiStudioHub.id
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

resource diagnosticsProject 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: aoaiStudioProject
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
