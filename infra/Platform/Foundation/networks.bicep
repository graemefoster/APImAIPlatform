targetScope = 'resourceGroup'

param vnetName string
param location string = resourceGroup().location

var addressSpace = '10.0.0.0/16'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
  }
}

resource apimNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'apim-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Secure_Client_communication_to_API_Management'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'Management_endpoint_for_Azure_portal_and_Powershell'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3443'
          sourceAddressPrefix: 'ApiManagement'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'Azure_Infrastructure_Load_Balancer'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6390'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'Dependency_on_Azure_Storage'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          priority: 140
          direction: 'Outbound'
        }
      }
      {
        name: 'Dependency_on_Azure_Sql'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'SQL'
          access: 'Allow'
          priority: 150
          direction: 'Outbound'
        }
      }
      {
        name: 'Dependency_on_Azure_KeyVault'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '433'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureKeyVault'
          access: 'Allow'
          priority: 160
          direction: 'Outbound'
        }
      }
      {
        name: 'Publish_DiagnosticLogs_And_Metrics'
        properties: {
          description: 'API Management logs and metrics for consumption by admins and your IT team are all part of the management plane'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureMonitor'
          access: 'Allow'
          priority: 170
          direction: 'Outbound'
          destinationPortRanges: [
            '443'
            '1886'
          ]
        }
      }
    ]
  }
}

resource apimSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: 'apim-subnet'
  parent: vnet
  properties: {
    addressPrefix: cidrSubnet(addressSpace, 24, 0)
    networkSecurityGroup: {
      id: apimNsg.id
    }
  }
}

resource peSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: 'private-endpoints'
  parent: vnet
  properties: {
    addressPrefix: cidrSubnet(addressSpace, 24, 1)
    privateEndpointNetworkPolicies: 'Enabled'
  }
  dependsOn: [apimSubnet]
}

resource vnetIntegrationSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: 'vnet-integration'
  parent: vnet
  properties: {
    addressPrefix: cidrSubnet(addressSpace, 24, 2)
    delegations: [
      {
        name: 'AppServiceDelegation'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
  }
  dependsOn: [peSubnet]
}

resource vmSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: 'vm-subnet'
  parent: vnet
  properties: {
    addressPrefix: cidrSubnet(addressSpace, 24, 3)
  }
  dependsOn: [vnetIntegrationSubnet]
}

resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: 'AzureBastionSubnet'
  parent: vnet
  properties: {
    addressPrefix: cidrSubnet(addressSpace, 24, 4)
  }
  dependsOn: [vmSubnet]
}


resource openAiPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.openai.azure.com'
  location: 'global'

  resource vnetLink 'virtualNetworkLinks@2020-06-01' = {
    name: 'privatelink.openai.azure.com-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource kvPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'

  resource vnetLink 'virtualNetworkLinks@2020-06-01' = {
    name: 'privatelink.vaultcore.azure.net-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }

}

resource storageQueuePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.queue.${environment().suffixes.storage}'
  location: 'global'

  resource vnetLink 'virtualNetworkLinks@2020-06-01' = {
    name: 'privatelink.queue.azure.net-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource storageBlobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'

  resource vnetLink 'virtualNetworkLinks@2020-06-01' = {
    name: 'privatelink.blob.azure.net-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource storageTablePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.table.${environment().suffixes.storage}'
  location: 'global'

  resource vnetLink 'virtualNetworkLinks@2020-06-01' = {
    name: 'privatelink.table.azure.net-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource cosmosPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.documents.azure.com'
  location: 'global'

  resource vnetLink 'virtualNetworkLinks' = {
    name: 'privatelink.documents.azure.com-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource cogServicesPrivateDnsZoneId 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.cognitiveservices.azure.com'
  location: 'global'

  resource vnetLink 'virtualNetworkLinks' = {
    name: 'privatelink.cognitiveservices.azure.com-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource cogSearchPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.search.windows.net'
  location: 'global'

  resource vnetLink 'virtualNetworkLinks@2020-06-01' = {
    name: 'privatelink.search.windows.net-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource appServicePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'

  resource vnetLink 'virtualNetworkLinks@2020-06-01' = {
    name: 'privatelink.azurewebsites.net-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource apimPrivateDnsZoneId 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'azure-api.net'
  location: 'global'

  resource vnetLink 'virtualNetworkLinks@2020-06-01' = {
    name: 'privatelink.azurewebsites.net-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

output vnetId string = vnet.id
output apimSubnetId string = apimSubnet.id
output peSubnetId string = peSubnet.id
output openAiPrivateDnsZoneId string = openAiPrivateDnsZone.id
output vnetIntegrationSubnetId string = vnetIntegrationSubnet.id
output kvPrivateDnsZoneId string = kvPrivateDnsZone.id
output storageQueuePrivateDnsZoneId string = storageQueuePrivateDnsZone.id
output storageBlobPrivateDnsZoneId string = storageBlobPrivateDnsZone.id
output storageTablePrivateDnsZoneId string = storageTablePrivateDnsZone.id
output cosmosPrivateDnsZoneId string = cosmosPrivateDnsZone.id
output cogServicesPrivateDnsZoneId string = cogServicesPrivateDnsZoneId.id
output azureSearchPrivateDnsZoneId string = cogSearchPrivateDnsZone.id
output appServicePrivateDnsZoneId string = appServicePrivateDnsZone.id
output bastionSubnetId string = bastionSubnet.id
output apimPrivateDnsZoneName string = apimPrivateDnsZoneId.name
