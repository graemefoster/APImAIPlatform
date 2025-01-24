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
param azureSearchPrivateDnsZoneId string
param peSubnet string
param platformResourceGroupName string
param aiCentralResourceId string

var aiFoundryManagedIdentityName = '${aiFoundryHubName}-uami'

resource aiFoundryManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: aiFoundryManagedIdentityName
  location: location
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  scope: resourceGroup(platformResourceGroupName)
  name: appInsightsName
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

module aiFoundryRbac './uami-rbac.bicep' = {
  name: '${deployment().name}-rbac'
  params: {
    aiFoundryAzureSearch: azureSearch.name
    aiFoundryStorage: consumerStorage.name
    aiFoundryKeyVault: kv.name
    aiFoundryAcr: acr.name
    aiFoundryManagedIdentityName: aiFoundryManagedIdentityName
    location: location
  }
}

module platformRbac './uami-platform-rbac.bicep' = {
  name: '${deployment().name}-rbac'
  scope: resourceGroup(platformResourceGroupName)
  params: {
    aiFoundryManagedIdentityName: aiFoundryRbac.outputs.aiFoundryManagedIdentityName
    aiCentralName: aiCentralName
    azopenaiName: azopenaiName
    azureaiFoundryUsersGroupObjectId: azureaiFoundryUsersGroupObjectId
    appInsightsName: appInsightsName
    aiFoundryRg: resourceGroup().name
  }
}

//AI Foundry group needs access over the Search Service
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

resource aiFoundryHub 'Microsoft.MachineLearningServices/workspaces@2024-10-01-preview' = {
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

  dependsOn: [
    platformRbac
  ]

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
