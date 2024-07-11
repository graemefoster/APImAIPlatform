param textAnalyticsName string
param peSubnetId string
param cogServicesPrivateDnsZoneId string
param location string = resourceGroup().location
param kvName string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: kvName
}

resource textAnalytics 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: textAnalyticsName
  kind: 'TextAnalytics'
  location: location
  sku: {
    name: 'F0'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
    customSubDomainName: textAnalyticsName
    networkAcls: {
      defaultAction: 'Deny'
    }
  }
}

resource textAnalyticsConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'text-analytics-connection'
  parent: kv
  properties: {
    contentType: 'text/plain'
    value: textAnalytics.listKeys().key1
  }
}

resource tape 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: '${textAnalytics.name}-pe'
  location: location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${textAnalytics.name}-plsc'
        properties: {
          privateLinkServiceId: textAnalytics.id
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }

  resource dnsZoneGroup 'privateDnsZoneGroups' = {
    name: '${textAnalytics.name}-dnszg'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink.cognitiveservices.azure.com'
          properties: {
            privateDnsZoneId: cogServicesPrivateDnsZoneId
          }
        }
      ]
    } 
  }
}

output textAnalyticsUri string = textAnalytics.properties.endpoint
output textAnalyticsSecretUri string = textAnalyticsConnectionStringSecret.properties.secretUri
