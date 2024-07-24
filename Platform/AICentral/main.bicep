import { ConsumerNameToApimSubscriptionKey, ConsumerNameToClientIdMapping } from '../types.bicep'

param aiCentralAppName string
param location string = resourceGroup().location
param aspId string
param peSubnetId string
param vnetIntegrationSubnetId string
param platformKeyVaultName string
param appServiceDnsZoneId string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: platformKeyVaultName
}

resource aiCentralManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: '${aiCentralAppName}-uami'
  location: location
}

var kvSecretsReaderRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource kvSecretsReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiCentralManagedIdentity.name, kvSecretsReaderRoleId, kv.id, resourceGroup().id)
  scope: kv
  properties: {
    principalId: aiCentralManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', kvSecretsReaderRoleId)
  }
}
resource aiCentral 'Microsoft.Web/sites@2023-12-01' = {
  location: location
  name: aiCentralAppName
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${aiCentralManagedIdentity.id}': {}
    }
  }
  kind: 'app'
  properties: {
    httpsOnly: true
    serverFarmId: aspId
    vnetRouteAllEnabled: true
    virtualNetworkSubnetId: vnetIntegrationSubnetId
    clientAffinityEnabled: false
    keyVaultReferenceIdentity: aiCentralManagedIdentity.id
    publicNetworkAccess: 'Disabled'
    siteConfig: {
      minTlsVersion: '1.2'
      alwaysOn: true
      vnetRouteAllEnabled: true
      ipSecurityRestrictions: []
      scmIpSecurityRestrictions: []
      linuxFxVersion: 'DOCKER|graemefoster/aicentral:0.18.3'
      healthCheckPath: '/healthz'
    }
  }
}

resource webappPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: '${aiCentral.name}-pe'
  location: location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${aiCentral.name}-private-link-service-connection'
        properties: {
          privateLinkServiceId: aiCentral.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }

  resource dnsGroup 'privateDnsZoneGroups@2022-11-01' = {
    name: '${aiCentral.name}-private-endpoint-dns'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: '${aiCentral.name}-private-endpoint-cfg'
          properties: {
            privateDnsZoneId: appServiceDnsZoneId
          }
        }
      ]
    }
  } 
}

output aiCentralResourceId string = aiCentral.id
output name string = aiCentral.name
