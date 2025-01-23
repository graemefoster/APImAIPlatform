targetScope = 'resourceGroup'

//This file is a bit of an experiementation into how AI Studio works. 
//I'm trying to build out prompt-flows / indexing / understand the security of everything

param location string
param aiFoundryHubName string
param acrName string
param azopenaiName string
param aiFoundryProjectName string
param logAnalyticsId string
param aiCentralName string
param azureaiFoundryUsersGroupObjectId string
param appInsightsName string
param azureMachineLearningServicePrincipalId string
param azureSearchPrivateDnsZoneId string
param peSubnet string
param platformResourceGroupName string
param aiCentralResourceId string

var aiFoundryManagedIdentityName = '${aiFoundryHubName}-uami'

resource aiFoundryManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: aiFoundryManagedIdentityName
  location: location
}

//deploy a few more components so we can demonstrate connecting AI Foundry to AI Search
resource azureSearch 'Microsoft.Search/searchServices@2024-03-01-Preview' = {
  name: '${aiFoundryHubName}-search'
  location: location
  sku: {
    name: 'basic'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aiFoundryManagedIdentity.id}': {}
    }
  }
  properties: {
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    networkRuleSet: {
      bypass: 'AzureServices' //Allow Azure Open AI Ingestion endpoint to callback to AI Search to index embedded items.
      ipRules: []
    }
    disabledDataExfiltrationOptions: [
      'All'
    ]
    publicNetworkAccess: 'disabled'
    hostingMode: 'default'
    semanticSearch: 'standard'
  }

  resource storageEndpoint 'sharedPrivateLinkResources' = {
    name: 'storage'
    properties: {
      groupId: 'blob'
      requestMessage: 'Azure Search would like to access your storage account'
      privateLinkResourceId: consumerStorage.id
      status: 'Approved'
    }
  }

  resource aiCentralEndpoint 'sharedPrivateLinkResources' = {
    name: 'aicentral'
    properties: {
      groupId: 'sites'
      requestMessage: 'Azure Search would like to access your AOAI resources via AI Central'
      privateLinkResourceId: aiCentralResourceId
      status: 'Approved'
    }
    dependsOn: [storageEndpoint] //doesn't like multiple updates at once
  }
}

//storage for AI Foundry
resource consumerStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: '${substring(replace('${aiFoundryHubName}', '-', ''), 0, 15)}stg'
  kind: 'StorageV2'
  location: location
  sku: { name: 'Standard_LRS' }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    defaultToOAuthAuthentication: true
  }
}

resource searchDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: azureSearch
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

//There is a lot of RBAC here... most of this has been built by trial and error.
//Some flows are front-channel, some are back-channel, some are side-channel (AOAI calls some of these endpoints)

//read access on the blobs for indexing (over a private endpoint)
//AI Foundry was observed to make calls to storage from its backend
resource storageReader 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
}

resource azSearchRbacOnStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${azureSearch.name}-storagereader-${consumerStorage.name}')
  scope: consumerStorage
  properties: {
    roleDefinitionId: storageReader.id
    principalId: aiFoundryManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

//private endpoint for AI Search
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: '${azureSearch.name}-pe'
  location: location
  properties: {
    subnet: {
      id: peSubnet
    }
    privateLinkServiceConnections: [
      {
        name: '${azureSearch.name}-private-link-service-connection'
        properties: {
          privateLinkServiceId: azureSearch.id
          groupIds: [
            'searchService'
          ]
        }
      }
    ]
  }

  resource dnsGroup 'privateDnsZoneGroups@2022-11-01' = {
    name: '${azureSearch.name}-private-endpoint-dns'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: '${azureSearch.name}-private-endpoint-cfg'
          properties: {
            privateDnsZoneId: azureSearchPrivateDnsZoneId
          }
        }
      ]
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' existing = {
  name: appInsightsName
}

resource aiCentral 'Microsoft.Web/sites@2023-12-01' existing = {
  scope: resourceGroup(platformResourceGroupName)
  name: aiCentralName
}

resource azOpenAI 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  scope: resourceGroup(platformResourceGroupName)
  name: azopenaiName
}

//AI Foundry can be provided an Azure Container Registry. 
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

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: replace('${aiFoundryHubName}-kv', '-', '')
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    publicNetworkAccess: 'disabled'
  }
}

resource storageBlobDataWriter 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
}

//AI Foundry was observed to make calls to write to storage from its backend
resource uamiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentity.name}-storagereader-${consumerStorage.name}')
  scope: consumerStorage
  properties: {
    roleDefinitionId: storageBlobDataWriter.id
    principalId: aiFoundryManagedIdentity.properties.principalId
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
  name: guid('${aiFoundryManagedIdentity.name}-acrpull-${acr.name}')
  scope: acr
  properties: {
    roleDefinitionId: acrPullRole.id
    principalId: aiFoundryManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource aiFoundryNetworkApprover 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'b556d68e-0be0-4f35-a333-ad7ee1ce17ea'
}

resource uamiRoleAssignmentNetworkApprover 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentity.name}-networkapprover-${resourceGroup().name}')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: aiFoundryNetworkApprover.id
    principalId: aiFoundryManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}


resource uamiRoleAssignmentAcrPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentity.name}-acrpush-${acr.name}')
  scope: acr
  properties: {
    roleDefinitionId: acrPushRole.id
    principalId: aiFoundryManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

//need network approver on platform components
module platformRbac './AIFoundryPlatformRBAC/main.bicep' = {
  name: '${deployment().name}-rbac'
  scope: resourceGroup(platformResourceGroupName)
  params: {
    aiFoundryManagedIdentityName: aiFoundryManagedIdentityName
    aiCentralName: aiCentralName
    aiFoundryPrincipalId: aiFoundryManagedIdentity.properties.principalId
    azopenaiName: azopenaiName
    azureaiFoundryUsersGroupObjectId: azureaiFoundryUsersGroupObjectId
  }
}

resource searchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
}

resource aiSearchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${azureaiFoundryUsersGroupObjectId}-contributor-${azureSearch.name}')
  properties: {
    roleDefinitionId: searchServiceContributor.id
    principalId: azureaiFoundryUsersGroupObjectId
    principalType: 'Group'
  }
}

resource searchIndexContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
}

resource aiSearchIndexContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${azureaiFoundryUsersGroupObjectId}-indexContributor-${azureSearch.name}')
  scope: azureSearch
  properties: {
    roleDefinitionId: searchIndexContributor.id
    principalId: azureaiFoundryUsersGroupObjectId
    principalType: 'Group'
  }
}

// For AI Studio PromptFlows - these should use the UAMI and need to query indexes
resource searchIndexReader 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
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

//https://learn.microsoft.com/en-gb/azure/ai-studio/how-to/disable-local-auth?tabs=portal&WT.mc_id=Portal-Microsoft_Azure_MLTeamAccounts#scenarios-for-hub-storage-account-role-assignments
//grant the RBAC for the users-group to be able to write promptflows
resource storageBlobDataContributor 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}
resource storageFileDataPrivilegedContributor 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
}

resource aoaiUsersStorageDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${azureaiFoundryUsersGroupObjectId}-storage-data-contributor-${consumerStorage.name}')
  scope: consumerStorage
  properties: {
    roleDefinitionId: storageBlobDataContributor.id
    principalId: azureaiFoundryUsersGroupObjectId
    principalType: 'Group'
  }
}
resource aoaiUsersStorageDataFileContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${azureaiFoundryUsersGroupObjectId}-storage-file-privileged-contributor-${consumerStorage.name}')
  scope: consumerStorage
  properties: {
    roleDefinitionId: storageFileDataPrivilegedContributor.id
    principalId: azureaiFoundryUsersGroupObjectId
    principalType: 'Group'
  }
}

//when I try create compute I am told I need Contributor on the ACR, and KV Administrator on the KV
var kvAdministrator = '00482a5a-887f-4fb3-b363-3b7fe8e74483'
resource kvAdministratorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: kvAdministrator
}

resource kvContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentity.name}-kvadministrator-${kv.name}')
  scope: kv
  properties: {
    roleDefinitionId: kvAdministratorRole.id
    principalId: aiFoundryManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource contributor 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
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

//give Azure AI Studio appid (0736f41a-0425-4b46-bdb5-1563eff02385) read access to backing services
//so it can check private endpoint status
resource readerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
}

resource aiFoundryReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${azureMachineLearningServicePrincipalId}-reader-${resourceGroup().name}')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: readerRole.id
    principalId: azureMachineLearningServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource aiFoundryIdentityContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${aiFoundryManagedIdentityName}-contributor-${resourceGroup().name}')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: contributor.id
    principalId: aiFoundryManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource aiFoundryHub 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = {
  //2024-07-01-preview
  name: aiFoundryHubName
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aiFoundryManagedIdentity.id}': {}
    }
  }
  kind: 'hub'
  properties: {
    allowPublicAccessWhenBehindVnet: true
    description: 'AI Studio project for the AI Ops Accelerator'
    friendlyName: aiFoundryHubName
    keyVault: kv.id
    systemDatastoresAuthMode: 'identity' //RBAC for accessing datastores
    storageAccount: consumerStorage.id
    containerRegistry: acr.id
    applicationInsights: appInsights.id
    primaryUserAssignedIdentity: aiFoundryManagedIdentity.id
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
      target: 'https://${azureSearch.name}.search.windows.net'
      authType: 'AAD'
      isSharedToAll: true
      useWorkspaceManagedIdentity: true
      peRequirement: 'Required'
      metadata: {
        ApiType: 'Azure'
        ApiVersion: '2024-05-01-preview'
        DeploymentApiVersion: '2023-11-01'
        ResourceId: azureSearch.id
        Location: location
      }
    }
    dependsOn: [
      aoaiConnection
    ]
  }
  dependsOn: [
    platformRbac
  ]
}


//now spin up an AI Foundry project
resource aoaiFoundryProject 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: aiFoundryProjectName
  location: resourceGroup().location
  kind: 'project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'AI Studio project for the AI Ops Accelerator'
    friendlyName: aiFoundryProjectName
    hubResourceId: aiFoundryHub.id
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: aiFoundryHub
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
  scope: aoaiFoundryProject
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
