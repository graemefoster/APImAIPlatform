import { ConsumerNameToApimSubscriptionKey, ConsumerNameToClientIdMapping } from '../types.bicep'

param aiCentralAppName string
param location string = resourceGroup().location
param appInsightsName string
param aiGatewayUri string
param embeddingsDeploymentName string
param platformKeyVaultName string
param consumerNameToAPImSubscriptionSecretMapping ConsumerNameToApimSubscriptionKey[]
param consumerNameToClientIdMappings ConsumerNameToClientIdMapping[]
param textAnalyticsUri string
param textAnalyticsSecretUri string
param cosmosUri string
param queueUri string
param aiCentralUamiClientId string

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

module clientMappingModules 'expandConfig.bicep' = [
  for idx in range(0, length(consumerNameToClientIdMappings)): {
    name: '${deployment().name}-${idx}'
    params: {
      input: consumerNameToClientIdMappings[idx]
      parentIndex: idx
    }
  }
]

var productToClientMappings = [
  for idx in range(0, length(consumerNameToAPImSubscriptionSecretMapping)): [
    {
      name: 'AICentral__ClaimsToKeys__${idx}__SubscriptionKey'
      value: '@Microsoft.KeyVault(SecretUri=${consumerNameToAPImSubscriptionSecretMapping[idx].secretUri})'
    }
  ]
]

module flattened 'flattenConfigs.bicep' = {
  name: '${deployment().name}-flattened'
  params: {
    array1: productToClientMappings
    array2: [for idx in range(0, length(consumerNameToClientIdMappings)): clientMappingModules[idx].outputs.result]
  }
}

var allAppSettings = union(flattened.outputs.result, [
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
    name: 'AICentral__AISearchEmbeddingsDeploymentName'
    value: embeddingsDeploymentName
  }
  {
    name: 'AICentral__AISearchEmbeddingsOpenAIApiVersion'
    value: '2024-04-01-preview'
  }
  {
    name: 'AICentral__StorageUri'
    value: queueUri
  }
  {
    name: 'AICentral__TextAnalyticsKey'
    value: '@Microsoft.KeyVault(SecretUri=${textAnalyticsSecretUri})'
  }
  {
    name: 'AICentral__CosmosAccountEndpoint'
    value: cosmosUri
  }
  {
    name: 'AICentral__UserAssignedManagedIdentityId'
    value: aiCentralUamiClientId
  }
  {
    name: 'EnableAICentralSummaryWebPage'
    value: 'false'
  }
  {
    name: 'WEBSITE_HEALTHCHECK_MAXPINGFAILURES'
    value: '10'
  }
  {
    name: 'ASPNETCORE_FORWARDEDHEADERS_ENABLED'
    value: 'true'
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
