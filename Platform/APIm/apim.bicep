targetScope = 'resourceGroup'

param apimName string
param apimPublisherEmail string
param apimPublisherName string
param apimSubnetId string

param appInsightsName string
param logAnalyticsWorkspaceName string

param location string = resourceGroup().location

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    publicNetworkAccess: 'Enabled'
    virtualNetworkConfiguration: {
      subnetResourceId: apimSubnetId
    }
    virtualNetworkType: 'External'
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource apimDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diagnostics'
  scope: apim
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        categoryGroup: 'allLogs'
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

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

//setup an APIm app-insights logger
resource appInsightsLogger 'Microsoft.ApiManagement/service/loggers@2023-05-01-preview' = {
  name: 'applicationInsights'
  parent: apim
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights Logger'
    credentials: {
      instrumentationKey: appInsights.properties.InstrumentationKey
    }
    resourceId: appInsights.id
    metrics: true
  }
}

output apimId string = apim.id
output apimName string = apim.name
