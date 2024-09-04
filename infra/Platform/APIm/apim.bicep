targetScope = 'resourceGroup'

param apimName string
param apimPublisherEmail string
param apimPublisherName string
param apimSubnetId string
param tenantId string
param platformManagedIdentityId string

param appInsightsName string
param logAnalyticsWorkspaceName string

param location string = resourceGroup().location

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${platformManagedIdentityId}': {}
    }
  }
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
    virtualNetworkType: 'Internal'
  }

  resource namedValue 'namedValues' = {
    name: 'tenantId'
    properties: {
      displayName: 'tenantId'
      value: tenantId
    }
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

resource appInsightsLoggerNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  name: 'appInsightsInstrumentationKey'
  parent: apim
  properties: {
    displayName: 'appInsightsInstrumentationKey'
    value: appInsights.properties.InstrumentationKey
    secret: true
  }
}

//setup an APIm app-insights logger
resource appInsightsLogger 'Microsoft.ApiManagement/service/loggers@2023-05-01-preview' = {
  name: 'applicationInsights'
  parent: apim
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights Logger'
    credentials: {
      instrumentationKey: '{{appInsightsInstrumentationKey}}' //stops creating a new named value on each deployment.
    }
    resourceId: appInsights.id
    metrics: true
  }
  dependsOn: [
    appInsightsLoggerNamedValue
  ]
}

output apimId string = apim.id
output apimName string = apim.name
output apimUri string = apim.properties.gatewayUrl
