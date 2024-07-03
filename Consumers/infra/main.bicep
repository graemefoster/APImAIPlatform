targetScope='resourceGroup'

param consumerSlug string
param logAnalyticsId string
param location string = resourceGroup().location

resource searchService 'Microsoft.Search/searchServices@2024-03-01-preview' = {
  name: '${consumerSlug}-search'
  location: location
  sku: {
    name: 'basic'
  }
  properties: {
    hostingMode: 'default'
    semanticSearch: 'free'
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http403'
      }
    }
    publicNetworkAccess: 'enabled'
  }
}

//no support for an index in Bicep unfortunately.


resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: searchService
  name: 'diagnostics'
  properties: {
    workspaceId: logAnalyticsId
    logs: [
      {
        category: 'OperationLogs'
        enabled: true
      }
    ]
  }
}
