//optional VM - allows us to keep everything private

param location string = resourceGroup().location

param bastionName string
param vmName string
param vmSize string
param vmImage string
param vnetId string
param vnetSubnetId string
param bastionSubnetId string
param vmUser string

@secure()
param vmPassword string

resource bastionPip 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: '${bastionName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2024-01-01' = {
  name: bastionName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnetSubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: vmImage
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: vmUser
      adminPassword: vmPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}
