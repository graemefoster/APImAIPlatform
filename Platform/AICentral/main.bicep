import { ConsumerNameToApimSubscriptionKey, ConsumerNameToClientIdMapping } from '../types.bicep'

param aiCentralAppName string
param location string = resourceGroup().location
param aspId string
param peSubnetId string
param vnetIntegrationSubnetId string
param platformKeyVaultName string
param storageAccountName string
param appServiceDnsZoneId string
param cosmosName string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: platformKeyVaultName
}

resource aiCentralManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: '${aiCentralAppName}-uami'
  location: location
}

//RBAC for AI Central Managed Identity to write audit logs
resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosName

  resource cosmosBuiltInDataContributorRole 'sqlRoleDefinitions' existing = {
    name: '00000000-0000-0000-0000-000000000002'
  }

  resource aiCentralWrite 'sqlRoleAssignments' = {
    name: guid('aiCentralWrite', cosmos.id)
    properties: {
      roleDefinitionId: cosmosBuiltInDataContributorRole.id //Cosmos DB Built-in Data Contributor. You can create a custom role to limit this
      principalId: aiCentralManagedIdentity.properties.principalId
      scope: cosmos.id
    }
  }
}

//RBAC for writing and reading queue messages for background processing
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

//AI Central checks if queues exist before writing. I think this needs reader role on the storage
var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
resource aiCentralQueueReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiCentralManagedIdentity.name, readerRoleId, storage.id, resourceGroup().id)
  scope: storage
  properties: {
    principalId: aiCentralManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
  }
}

var queueContributorRoleId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
resource aiCentralQueueContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiCentralManagedIdentity.name, queueContributorRoleId, storage.id, resourceGroup().id)
  scope: storage
  properties: {
    principalId: aiCentralManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', queueContributorRoleId)
  }
}

//For reading the Language Service secret from Key Vault
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

//For reading the Cosmos metadata to check the database exists
resource aiCentralCosmosReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiCentralManagedIdentity.name, readerRoleId, cosmos.id, resourceGroup().id)
  scope: cosmos
  properties: {
    principalId: aiCentralManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
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
      linuxFxVersion: 'DOCKER|graemefoster/aicentral:0.20.0'
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
output aiCentralUamiClientId string = aiCentralManagedIdentity.properties.clientId
