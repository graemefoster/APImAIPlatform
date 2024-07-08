import { ConsumerNameToApimSubscriptionKey, ConsumerNameToClientIdMapping } from '../types.bicep'

param aiCentralAppName string
param location string = resourceGroup().location
param aspId string
param vnetIntegrationSubnetId string
param appInsightsName string
param aiGatewayUri string
param platformKeyVaultName string
param consumerNameToAPImSubscriptionSecretMapping ConsumerNameToApimSubscriptionKey[]
param consumerNameToClientIdMapping ConsumerNameToClientIdMapping[]

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

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

var productToClientMappings =  [
  for idx in range(0, length(consumerNameToAPImSubscriptionSecretMapping)): [
    {
      name: 'AICentral__ClaimsToKeys__${idx}__ClaimValue'
      value: filter(consumerNameToClientIdMapping, item => item.consumerName == consumerNameToAPImSubscriptionSecretMapping[idx].consumerName)[0].entraClientId
    }
    {
      name: 'AICentral__ClaimsToKeys__${idx}__SubscriptionKey'
      value: '@Microsoft.KeyVault(SecretUri=${consumerNameToAPImSubscriptionSecretMapping[idx].secretUri})'
    }
  ]
]

var allAppSettings = union(flatten(productToClientMappings), [
  {
    name: 'DOCKER_REGISTRY_SERVER_URL'
    value: 'https://index.docker.io/v1'
  }
  {
    name: 'ASPNETCORE_ENVIRONMENT'
    value: 'APImProxyWithCosmosLogging'
  }
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsights.properties.ConnectionString
  }
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: appInsights.properties.InstrumentationKey
  }
  {
    name: 'WEBSITES_PORT'
    value: '8080'
  }
  {
    name: 'AICentral__LanguageEndpoint'
    value: aiGatewayUri
  }
  {
    name: 'AICentral__TenantId'
    value: subscription().tenantId
  }
  {
    name: 'EnableAICentralSummaryWebPage'
    value: 'false'
  }
])

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
    siteConfig: {
      minTlsVersion: '1.2'
      alwaysOn: true
      vnetRouteAllEnabled: true
      ipSecurityRestrictions: []
      scmIpSecurityRestrictions: []
      linuxFxVersion: 'DOCKER|graemefoster/aicentral:0.17.0-enhanced-backend0015'
      appSettings: allAppSettings
    }
  }
}
