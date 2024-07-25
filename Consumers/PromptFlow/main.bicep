param logAnalyticsId string
param aiCentralHostName string
param appInsightsName string
param appServicePlanId string
param acrName string
param webAppName string
param peSubnet string
param vnetIntegrationSubnet string
param location string = resourceGroup().location
param acrManagedIdentityName string
param kvDnsZoneId string
param azureSearchPrivateDnsZoneId string
param aiCentralResourceId string
param platformRg string

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: acrManagedIdentityName
  scope: resourceGroup(platformRg)
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: acrName
  scope: resourceGroup(platformRg)
}

resource appi 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
  scope: resourceGroup(platformRg)
}

resource consumerStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: replace('${webAppName}-stg', '-', '')
  kind: 'StorageV2'
  location: location
  sku: {name: 'Standard_LRS'}
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    defaultToOAuthAuthentication: true
  }
}

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  location: location
  name: replace('${webAppName}-kv', '-', '')
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

resource kvpe 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: '${kv.name}-pe'
  location: location
  properties: {
    subnet: {
      id: peSubnet
    }
    privateLinkServiceConnections: [
      {
        name: '${kv.name}-plsc'
        properties: {
          privateLinkServiceId: kv.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }

  resource dnsZoneGroup 'privateDnsZoneGroups' = {
    name: '${kv.name}-dnszg'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink.vaultcore.azure.net'
          properties: {
            privateDnsZoneId: kvDnsZoneId
          }
        }
      ]
    }
  
  }
}

resource kvSecretsReaderIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: '${webAppName}-uami'
  location: location
}

var kvSecretsReaderRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource kvSecretsReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kvSecretsReaderIdentity.name, kvSecretsReaderRoleId, kv.id, resourceGroup().id)
  scope: kv
  properties: {
    principalId: kvSecretsReaderIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', kvSecretsReaderRoleId)
  }
}

resource azureSearch 'Microsoft.Search/searchServices@2024-03-01-Preview' = {
  name: '${webAppName}-search'
  location: location
  sku: {
    name: 'basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    disableLocalAuth: true
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
  }
}

//read access on the blobs for indexing (over a private endpoint)
resource storageReader 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
}

resource azSearchRbacOnStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${azureSearch.name}-storagereader-${consumerStorage.name}')
  scope: consumerStorage
  properties: {
    roleDefinitionId: storageReader.id
    principalId: azureSearch.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

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

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
      '${kvSecretsReaderIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlanId
    vnetImagePullEnabled: false
    virtualNetworkSubnetId: vnetIntegrationSubnet
    keyVaultReferenceIdentity: kvSecretsReaderIdentity.id
    siteConfig: {
      alwaysOn: true
      vnetRouteAllEnabled: true
      linuxFxVersion: 'DOCKER|promptflows/consumer-1:0.8'
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: uami.properties.clientId
      appCommandLine: 'bash start.sh'
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: acr.properties.loginServer
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appi.properties.ConnectionString
        }
        {
          name: 'WEBSITES_PORT'
          value: '8080'
        }
        {
          name: 'OPEN_AI_CONNECTION_BASE'
          value: aiCentralHostName
        }
        {
          name: 'PROMPTFLOW_SERVING_ENGINE'
          value: 'fastapi'
        }
      ]
    }
  }
}

resource searchRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
}

resource appServiceRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${webApp.name}-search-${azureSearch.id}')
  scope: azureSearch
  properties: {
    roleDefinitionId: searchRole.id
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: webApp
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

//TODO - this doesn't always work first time... the identity doesn't exist. So you might need to run the template twice.
//I could make it work with a User Assigned Managed Identity, but PromptFlow doesn't support this.
resource identity 'Microsoft.ManagedIdentity/identities@2023-07-31-preview' existing = {
  scope: webApp
  name: 'default'
}

output promptFlowIdentityPrincipalId string = identity.properties.clientId
