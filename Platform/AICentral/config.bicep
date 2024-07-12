import { ConsumerNameToApimSubscriptionKey, ConsumerNameToClientIdMapping } from '../types.bicep'

param aiCentralAppName string
param location string = resourceGroup().location
param appInsightsName string
param aiGatewayUri string
param platformKeyVaultName string
param consumerNameToAPImSubscriptionSecretMapping ConsumerNameToApimSubscriptionKey[]
param consumerNameToClientIdMappings ConsumerNameToClientIdMapping[]
param textAnalyticsUri string
param cosmosConnectionStringSecretUri string
param storageConectionStringSecretUri string
param textAnalyticsSecretUri string

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

var productToClientMappings = [
  for idx in range(0, length(consumerNameToAPImSubscriptionSecretMapping)): [
    {
      name: 'AICentral__ClaimsToKeys__${idx}__ClaimValue'
      value: filter(
        consumerNameToClientIdMappings,
        item => item.consumerName == consumerNameToAPImSubscriptionSecretMapping[idx].consumerName
      )[0].entraClientId
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
    name: 'AICentral__ApimEndpointUri'
    value: aiGatewayUri
  }
  {
    name: 'AICentral__TenantId'
    value: subscription().tenantId
  }
  {
    name: 'AICentral__IncomingClaimName'
    value: 'appid'
  }
  {
    name: 'AICentral__TextAnalyticsEndpoint'
    value: textAnalyticsUri
  }
  {
    name: 'AICentral__StorageConnectionString'
    value: '@Microsoft.KeyVault(SecretUri=${storageConectionStringSecretUri})'
  }
  {
    name: 'AICentral__TextAnalyticsKey'
    value: '@Microsoft.KeyVault(SecretUri=${textAnalyticsSecretUri})'
  }
  {
    name: 'AICentral__CosmosConnectionString'
    value: '@Microsoft.KeyVault(SecretUri=${cosmosConnectionStringSecretUri})'
  }
  {
    name: 'EnableAICentralSummaryWebPage'
    value: 'false'
  }
  {
    name: 'WEBSITE_HEALTHCHECK_MAXPINGFAILURES'
    value: '10'
  }
])

var realAppSettings = reduce(allAppSettings, {}, (acc, setting) => union(acc, { '${setting.name}': setting.value }))

resource aiCentral 'Microsoft.Web/sites@2023-12-01' existing = {
  name: aiCentralAppName
}

resource aiCentralConfig 'Microsoft.Web/sites/config@2023-12-01' = {
  name: 'appsettings'
  parent: aiCentral
  properties: realAppSettings
}
