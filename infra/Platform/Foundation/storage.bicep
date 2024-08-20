param storageName string
param tableDnsZoneId string
param blobDnsZoneId string
param queueDnsZoneId string
param peSubnetId string
param location string = resourceGroup().location

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

//The queue is used by AI Central for logging using a background processor.
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

  resource queueDns 'privateDnsZoneGroups' = {
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

resource blobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: '${storageName}-blob-pe'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${storageName}-blob-plsc'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }

  resource blobDns 'privateDnsZoneGroups' = {
    name: '${storageName}-queue-dnszg'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink.blob.${storageName}'
          properties: {
            privateDnsZoneId: blobDnsZoneId
          }
        }
      ]
    }
  }
}

resource tablePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: '${storageName}-table-pe'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${storageName}-table-plsc'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'table'
          ]
        }
      }
    ]
  }
  resource tableDns 'privateDnsZoneGroups' = {
    name: '${storageName}-table-dnszg'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink.table.${storageName}'
          properties: {
            privateDnsZoneId: tableDnsZoneId
          }
        }
      ]
    }
  }
}

output queueUri string = storage.properties.primaryEndpoints.queue
output storageName string = storage.name
