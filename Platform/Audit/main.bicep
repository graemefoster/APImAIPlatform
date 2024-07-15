param cosmosName string
param peSubnetId string
param cosmosPrivateDnsZoneId string
param location string = resourceGroup().location
param kvName string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: kvName
}

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: cosmosName
  location: location
  properties: {
    publicNetworkAccess: 'Disabled'
    databaseAccountOfferType: 'Standard'
    locations: [{ failoverPriority: 0, locationName: location, isZoneRedundant: false }]
  }

  resource loggingDatabase 'sqlDatabases' = {
    name: 'aoaiLogs'
    location: location
    properties: {
      options: {
        autoscaleSettings: {
          maxThroughput: 4000
        }
      }
      resource: {
        id: 'aoaiLogs'
        createMode: 'Default'
      }
    }

    resource loggingContainer 'containers' = {
      name: 'aoaiLogContainer'
      location: location
      properties: {
        resource: {
          id: 'aoaiLogContainer'
          partitionKey: {
            paths: [
              '/DeploymentName'
            ]
            kind: 'Hash'
          }
        }
        options: {
          autoscaleSettings: {
            maxThroughput: 4000
          }
        }
      }
    }
  }
}

resource connectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'auditdb-connection'
  parent: kv
  properties: {
    contentType: 'text/plain'
    value: cosmos.listConnectionStrings().connectionStrings[0].connectionString
  }
}

resource kvpe 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: '${cosmos.name}-pe'
  location: location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${cosmos.name}-plsc'
        properties: {
          privateLinkServiceId: cosmos.id
          groupIds: [
            'sql'
          ]
        }
      }
    ]
  }

  resource dnsZoneGroup 'privateDnsZoneGroups' = {
    name: '${cosmos.name}-dnszg'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink.vaultcore.azure.net'
          properties: {
            privateDnsZoneId: cosmosPrivateDnsZoneId
          }
        }
      ]
    }
  }
}
output cosmosConnectionStringSecretUri string = connectionStringSecret.properties.secretUri
