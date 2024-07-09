param storageName string
param queueDnsZoneId string
param peSubnetId string

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: resourceGroup().location
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
