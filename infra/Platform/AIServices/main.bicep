targetScope = 'resourceGroup'

param aiServicesName string
param location string = resourceGroup().location
param logAnalyticsId string

resource aiServicesAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: aiServicesName
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: toLower(aiServicesName)
    apiProperties: {
    }
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: aiServicesAccount
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

output aiServicesName string = aiServicesAccount.name
