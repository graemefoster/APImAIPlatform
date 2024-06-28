targetScope = 'resourceGroup'

param apimName string

param appInsightsResourceGroup string
param appInsightsName string

param logAnalyticsWorkspaceResourceGroup string
param logAnalyticsWorkspaceName string

resource apim 'Microsoft.ApiManagement/service@2019-12-01' existing = {
  name: apimName
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  scope: resourceGroup(logAnalyticsWorkspaceResourceGroup)
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

resource appInsights 'Microsoft.Insights/components@2015-05-01' existing = {
  name: appInsightsName
  scope: resourceGroup(appInsightsResourceGroup)
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
