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
param platformRg string

var promptFlowIdentityName = '${webAppName}-uami'

resource promptFlowIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: promptFlowIdentityName
  location: location
}

resource acrUami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
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

var kvSecretsReaderRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource kvSecretsReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(promptFlowIdentity.name, kvSecretsReaderRoleId, kv.id, resourceGroup().id)
  scope: kv
  properties: {
    principalId: promptFlowIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', kvSecretsReaderRoleId)
  }
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${acrUami.id}': {}
      '${promptFlowIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlanId
    vnetImagePullEnabled: false
    virtualNetworkSubnetId: vnetIntegrationSubnet
    keyVaultReferenceIdentity: promptFlowIdentity.id
    siteConfig: {
      alwaysOn: true
      vnetRouteAllEnabled: true
      linuxFxVersion: 'DOCKER|promptflows/consumer-1:0.9'
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: acrUami.properties.clientId
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
        {
          name: 'AZURE_CLIENT_ID'
          value: promptFlowIdentity.properties.clientId
        }
      ]
    }
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

output promptFlowAppIdentityId string = promptFlowIdentity.properties.clientId
