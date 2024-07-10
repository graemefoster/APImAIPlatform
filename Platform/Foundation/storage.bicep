param storageName string
param queueDnsZoneId string
param peSubnetId string
param kvName string
param location string = resourceGroup().location

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name:  kvName
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    defaultToOAuthAuthentication: true
  }
}

resource storageConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'logging-queue'
  parent: kv
  properties: {
    contentType: 'text/plain'
    value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storage.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
  }
}

resource queuePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: '${storageName}-queue-pe'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${storageName}-queue-plsc'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'queue'
          ]
        }
      }
    ]
  }

  resource dns 'privateDnsZoneGroups' = {
    name: '${storageName}-queue-dnszg'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink.queue.${storageName}'
          properties: {
            privateDnsZoneId: queueDnsZoneId
          }
        }
      ]
    }
  }
}


output storageQueueConnectionString string = storage.properties.primaryEndpoints.queue
output storageConectionStringSecretUri string = storageConnectionStringSecret.properties.secretUri
