param logAnalyticsId string
param apimName string
param apimUsername string
param appInsightsName string
param appServicePlanId string
param acrName string
param webAppName string
param vnetIntegrationSubnet string
param location string = resourceGroup().location
param acrManagedIdentityName string

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: acrManagedIdentityName
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: acrName
}

resource appi 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimName
}

resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' existing = {
  parent: apim
  name: apimUsername
}

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  location: location
  name: '${webAppName}-kv'
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
  }
  resource apimProductKey 'secrets' = {
    name: 'apim-product-key'
    properties: {
      value: apimSubscription.properties.primaryKey
      contentType: 'text/plain'
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
    }
  }
  properties: {
    serverFarmId: appServicePlanId
    vnetImagePullEnabled: false
    virtualNetworkSubnetId: vnetIntegrationSubnet
    siteConfig: {
      alwaysOn: true
      vnetRouteAllEnabled: true
      linuxFxVersion: 'DOCKER|promptflows/consumer-1:latest'
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: uami.properties.clientId
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: acr.properties.loginServer
        }
        {
          name: 'APPINSIGHTS_CONNECTION_STRING'
          value: appi.properties.ConnectionString
        }
        {
          name: 'WEBSITES_PORT'
          value: '8080'
        }
        {
          name: 'OPEN_AI_CONNECTION_API_KEY'
          value: apimSubscription.properties.primaryKey
        }
        {
          name: 'OPEN_AI_CONNECTION_BASE'
          value: apim.properties.gatewayUrl
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
