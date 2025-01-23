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
param azureAiStudioUsersGroupObjectId string
param appInsightsName string
param azureMachineLearningServicePrincipalId string
param aiServicesName string

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' existing = {
  name: appInsightsName
}

resource aiSearch 'Microsoft.Search/searchServices@2024-03-01-Preview' existing = {
  name: aiSearchName
  scope: resourceGroup(aiSearchRg)
}

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: aiServicesName
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

resource cognitiveServicesOpenAIContributor 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'a001fd3d-188f-4b5d-821b-7da978bf7442'
}

resource aoaiUsersCogServicesOAIContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${azureAiStudioUsersGroupObjectId}-cogsvcaoaicontrib-${aiServices.name}')
  scope: aiServices
  properties: {
    roleDefinitionId: cognitiveServicesOpenAIContributor.id
    principalId: azureAiStudioUsersGroupObjectId
    principalType: 'Group'
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

resource uamiRoleAICentralAssignmentNetworkApprover 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiStudioManagedIdentity.name}-networkapprover-${aiCentral.name}')
  scope: aiCentral
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
    aiStudioManagedIdentityName: aiStudioManagedIdentity.name
    aiStudioManagedIdentityRg: resourceGroup().name
    azureAiStudioUsersGroupObjectId: azureAiStudioUsersGroupObjectId
    azureMachineLearningServicePrincipalId: azureMachineLearningServicePrincipalId
  }
}

//https://learn.microsoft.com/en-gb/azure/ai-studio/how-to/disable-local-auth?tabs=portal&WT.mc_id=Portal-Microsoft_Azure_MLTeamAccounts#scenarios-for-hub-storage-account-role-assignments
//grant the RBAC for the users-group to be able to write promptflows
resource storageBlobDataContributor 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}
resource storageFileDataPrivilegedContributor 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
}

resource aoaiUsersStorageDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${azureAiStudioUsersGroupObjectId}-storage-data-contributor-${storage.name}')
  scope: storage
  properties: {
    roleDefinitionId: storageBlobDataContributor.id
    principalId: azureAiStudioUsersGroupObjectId
    principalType: 'Group'
  }
}
resource aoaiUsersStorageDataFileContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${azureAiStudioUsersGroupObjectId}-storage-file-privileged-contributor-${storage.name}')
  scope: storage
  properties: {
    roleDefinitionId: storageFileDataPrivilegedContributor.id
    principalId: azureAiStudioUsersGroupObjectId
    principalType: 'Group'
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

//AI Studio uses the /ingestion endpoint which isn't covered in Cog Svc users. This is performed as the AI Studio user
resource aoaiContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: 'a001fd3d-188f-4b5d-821b-7da978bf7442'
}

resource aoaiContributorRoleForAIStudioGroup 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${azureAiStudioUsersGroupObjectId}-aoaiContributor-${azOpenAI.name}')
  scope: azOpenAI
  properties: {
    roleDefinitionId: aoaiContributorRole.id
    principalId: azureAiStudioUsersGroupObjectId
    principalType: 'Group'
  }
}

//when I try create compute I am told I need Contributor on the ACR, and KV Administrator on the KV
var kvAdministrator = '00482a5a-887f-4fb3-b363-3b7fe8e74483'
resource kvAdministratorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: kvAdministrator
}

resource kvContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiStudioManagedIdentity.name}-kvadministrator-${kv.name}')
  scope: kv
  properties: {
    roleDefinitionId: kvAdministratorRole.id
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

//give Azure AI Studio appid (0736f41a-0425-4b46-bdb5-1563eff02385) read access to backing services
//so it can check private endpoint status
resource readerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
}

resource aiStudioReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${azureMachineLearningServicePrincipalId}-reader-${resourceGroup().name}')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: readerRole.id
    principalId: azureMachineLearningServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource aiStudioIdentityContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiStudioManagedIdentityName}-contributor-${resourceGroup().name}')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: contributor.id
    principalId: aiStudioManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource aiStudioHub 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = {
  //2024-07-01-preview
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
    systemDatastoresAuthMode: 'identity' //RBAC for accessing datastores
    storageAccount: storage.id
    containerRegistry: acr.id
    applicationInsights: appInsights.id
    primaryUserAssignedIdentity: aiStudioManagedIdentity.id
    publicNetworkAccess: 'Enabled'
    managedNetwork: {
      isolationMode: 'AllowInternetOutbound'
      outboundRules: {
        Connection_AICentral: {
          type: 'PrivateEndpoint'
          destination: {
            serviceResourceId: aiCentral.id
            subresourceTarget: 'sites'
          }
          category: 'UserDefined'
        }
      }
    }
  }

  resource aoaiServicesConnection 'connections@2024-10-01-preview' = {
    name: aiServices.name
    properties: {
      category: 'AIServices'
      target: 'https://${aiCentral.properties.defaultHostName}' //  azOpenAI.properties.endpoint //needs deployment names exposed via AI Central to match ones in AOAI
      authType: 'ApiKey'
      isSharedToAll: true
      credentials: {
        key: aiServices.listKeys().key1
      }
      peRequirement: 'Required'
      useWorkspaceManagedIdentity: true
      metadata: {
        ApiType: 'Azure'
        ResourceId: aiServices.id
      }
    }
  }

  resource aoaiConnection 'connections@2024-10-01-preview' = {
    name: 'aiServicesConnection'
    properties: {
      category: 'AzureOpenAI'
      target: 'https://${aiCentral.properties.defaultHostName}' //  azOpenAI.properties.endpoint //needs deployment names exposed via AI Central to match ones in AOAI
      authType: 'AAD'
      isSharedToAll: true
      peRequirement: 'Required'
      useWorkspaceManagedIdentity: true
      metadata: {
        ApiType: 'Azure'
        ResourceId: azOpenAI.id
      }
    }
  }

  resource aiSearchConnection 'connections@2024-07-01-preview' = {
    name: 'aiSearchConnection'
    properties: {
      category: 'CognitiveSearch'
      target: 'https://${aiSearch.name}.search.windows.net'
      authType: 'AAD'
      isSharedToAll: true
      useWorkspaceManagedIdentity: true
      peRequirement: 'Required'
      metadata: {
        ApiType: 'Azure'
        ApiVersion: '2024-05-01-preview'
        DeploymentApiVersion: '2023-11-01'
        ResourceId: aiSearch.id
        Location: location
      }
    }
    dependsOn: [
      aoaiServicesConnection
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
