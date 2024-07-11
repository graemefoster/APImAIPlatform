targetScope = 'resourceGroup'

import { AzureOpenAIResourceOutput } from '../types.bicep'

param aoaiName string
param privateDnsZoneId string
param privateEndpointSubnetId string
param location string = resourceGroup().location
param resourcePrefix string
param logAnalyticsId string

var aoaiResourceName = '${resourcePrefix}-${aoaiName}-aoai'

resource aoai 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: aoaiResourceName
  location: location
  kind: 'OpenAI'
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: true
    networkAcls: {
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
      bypass: 'None'
    }
    customSubDomainName: aoaiResourceName
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: aoai
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

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: '${aoai.name}-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'openai-private-link-service-connection'
        properties: {
          privateLinkServiceId: aoai.id
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }

  resource dnsGroup 'privateDnsZoneGroups@2022-11-01' = {
    name: 'openai-private-endpoint-dns'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'openai-private-endpoint-cfg'
          properties: {
            privateDnsZoneId: privateDnsZoneId
          }
        }
      ]
    }
  }
}

output aoaiInformation AzureOpenAIResourceOutput = {
  resourceId: aoai.id
  resourceName: aoai.name
  inputName: aoaiName
  resourceGroupName: resourceGroup().name
  endpoint: aoai.properties.endpoint
}
