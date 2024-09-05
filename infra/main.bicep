targetScope = 'subscription'

param platformResourceGroup string
param platformSlug string
param apimPublisherEmail string
param apimPublisherName string
param ghRepo string
param ghUsername string
param location string
param tenantId string
param environmentName string = 'dev'
param vectorizerEmbeddingsDeploymentName string

//we grant some additional permissions to this group to enable AI Studio to work
param azureAiStudioUsersGroupObjectId string

//Adds an API to APIm which appends product keys to incoming requests, then re-routes them to the AOAI API
param deploySubscriptionKeyAugmentingApi bool = false

//if we want a developer vm:
param deployDeveloperVm bool
param developerUsername string
@secure()
param developerPassword string

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${platformResourceGroup}-${environmentName}'
  location: location
}

resource consumerrg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${platformResourceGroup}-${environmentName}-consumer'
  location: location
}

var resourcePrefix = '${platformSlug}-${environmentName}-${substring(uniqueString(platformResourceGroup, platformSlug, deployment().name), 0, 5)}'
var vnetName = '${resourcePrefix}-vnet'
var apimName = '${resourcePrefix}-apim'
var aspName = '${resourcePrefix}-asp'
var platformKeyVaultName = '${resourcePrefix}kv'
var appInsightsName = '${resourcePrefix}-appi'
var webappname = '${resourcePrefix}-pf-app'
var aiCentralAppName = '${resourcePrefix}-aic-app'
var acrName = replace('${resourcePrefix}-acr', '-', '')
var aiStudioAcrName = replace('${resourcePrefix}-aistudioacr', '-', '')
var storageName = replace('${resourcePrefix}-stg', '-', '')
var cosmosName = replace('${resourcePrefix}-cosmos', '-', '')
var textAnalyticsName = replace('${resourcePrefix}-textan', '-', '')
var logAnalyticsWorkspaceName = '${resourcePrefix}-logs'
var deploymentIdentityName = '${resourcePrefix}-uami'
var acrPullIdentityName = '${resourcePrefix}-acrpuller-uami'

module platformJsonToBicepTypes 'jsonParametersToBicep.bicep' = {
  name: '${deployment().name}-jsonToBicep'
  scope: rg
}

module monitoring 'Platform/Foundation/monitoring.bicep' = {
  name: '${deployment().name}-monitoring'
  scope: rg
  params: {
    appInsightsName: appInsightsName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    location: location
  }
}

module network 'Platform/Foundation/networks.bicep' = {
  name: '${deployment().name}-network'
  scope: rg
  params: {
    vnetName: vnetName
  }
}

module platformKeyVault 'Platform/Foundation/kv.bicep' = {
  name: '${deployment().name}-platformkv'
  scope: rg
  params: {
    keyvaultName: platformKeyVaultName
    kvDnsZoneId: network.outputs.kvPrivateDnsZoneId
    peSubnetId: network.outputs.peSubnetId
    location: location
    platformName: platformSlug
  }
}

module storage 'Platform/Foundation/storage.bicep' = {
  name: '${deployment().name}-storage'
  scope: rg
  params: {
    peSubnetId: network.outputs.peSubnetId
    queueDnsZoneId: network.outputs.storageQueuePrivateDnsZoneId
    blobDnsZoneId: network.outputs.storageBlobPrivateDnsZoneId
    tableDnsZoneId: network.outputs.storageTablePrivateDnsZoneId
    storageName: storageName
    location: location
  }
}

module cosmos 'Platform/Audit/main.bicep' = {
  name: '${deployment().name}-cosmos'
  scope: rg
  params: {
    peSubnetId: network.outputs.peSubnetId
    cosmosName: cosmosName
    cosmosPrivateDnsZoneId: network.outputs.cosmosPrivateDnsZoneId
    location: location
  }
}

module textAnalytics 'Platform/Audit/text-analytics.bicep' = {
  name: '${deployment().name}-textAnalytics'
  scope: rg
  params: {
    kvName: platformKeyVault.outputs.kvName
    peSubnetId: network.outputs.peSubnetId
    textAnalyticsName: textAnalyticsName
    location: location
    cogServicesPrivateDnsZoneId: network.outputs.cogServicesPrivateDnsZoneId
  }
}

module aoais 'Platform/AOAI/aoais.bicep' = {
  name: '${deployment().name}-aoais'
  scope: rg
  params: {
    aoaiNames: platformJsonToBicepTypes.outputs.aoaiResources
    location: location
    privateDnsZoneId: network.outputs.openAiPrivateDnsZoneId
    privateEndpointSubnetId: network.outputs.peSubnetId
    resourcePrefix: resourcePrefix
    logAnalyticsId: monitoring.outputs.logAnalyticsId
  }
}

module azureOpenAiDeployments 'Platform/AOAI/aoaideployments.bicep' = {
  name: '${deployment().name}-aoaiDeployments'
  scope: rg
  params: {
    deploymentRequirements: platformJsonToBicepTypes.outputs.aoaiDeployments
    aoaiOutputs: aoais.outputs.aoaiResources
  }
  dependsOn: [aoais]
}

module apimFoundation 'Platform/APIm/apim.bicep' = {
  name: '${deployment().name}-apim'
  scope: rg
  params: {
    apimName: apimName
    appInsightsName: appInsightsName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    apimPublisherEmail: apimPublisherEmail
    apimPublisherName: apimPublisherName
    apimSubnetId: network.outputs.apimSubnetId
    tenantId: tenantId
    location: location
    platformManagedIdentityId: platformKeyVault.outputs.platformManagedIdentityId
    apimPrivateDnsZoneName: network.outputs.apimPrivateDnsZoneName
  }
}

// Consider cross subscription here. Sometimes we need to create more AOAI resource in other subscriptions.
// As long as the tenant is the same we can still use Entra to connect from APIm to AOAI.
module azureOpenAIApimBackends 'Platform/APIm/configureAoaiInApim.bicep' = {
  name: '${deployment().name}-aoaiBackends'
  scope: rg
  params: {
    apimName: apimFoundation.outputs.apimName
    aoaiResources: aoais.outputs.aoaiResources
    aoaiBackendPools: platformJsonToBicepTypes.outputs.apimBackendPools
  }
}

module azureOpenAIApis 'Platform/APIm/aoaiapis.bicep' = {
  name: '${deployment().name}-aoaiApi'
  scope: rg
  params: {
    apimName: apimFoundation.outputs.apimName
    azureOpenAiApis: platformJsonToBicepTypes.outputs.apiVersions
  }
  dependsOn: [azureOpenAIApimBackends]
}

module consumerHostingPlatform 'Platform/ConsumerOrchestratorHost/main.bicep' = {
  name: '${deployment().name}-consumerHosting'
  scope: rg
  params: {
    acrName: acrName
    location: location
    ghRepo: ghRepo
    ghUsername: ghUsername
    deploymentIdentityName: deploymentIdentityName
    environmentName: environmentName
    appServicePlanName: aspName
    acrPullIdentityName: acrPullIdentityName
  }
}

//TODO find a better way to get these out of JSON. This is a bit of a hack
var consumerNameToClientIdMappings = [
  {
    consumerName: 'consumer-1'
    entraClientIds: [consumerPromptFlow.outputs.promptFlowAppIdentityId]
  }
  {
    consumerName: 'aistudio'
    entraClientIds: filter(platformJsonToBicepTypes.outputs.consumerDemands, item => item.consumerName == 'aistudio')[0].constantAppIdIdentifiers[environmentName]
  }
]

module apimProductMappings 'Platform/Consumers/consumerDemands.bicep' = {
  name: '${deployment().name}-consumerDemands'
  scope: rg
  params: {
    apimName: apimFoundation.outputs.apimName
    consumerDemands: platformJsonToBicepTypes.outputs.consumerDemands
    mappedDemands: platformJsonToBicepTypes.outputs.platformMappedConsumerDemands
    apiNames: azureOpenAIApis.outputs.aoaiApiNames
    environmentName: environmentName
    platformKeyVaultName: platformKeyVaultName
    consumerNameToClientIdMappings: consumerNameToClientIdMappings
    platformUamiClientId: platformKeyVault.outputs.platformManagedIdentityClientId
  }
}

module subscriptionKeyAugmenting 'Platform/Consumers/subscriptionKeyAugmenter.bicep' = if (deploySubscriptionKeyAugmentingApi) {
  name: '${deployment().name}-subscriptionKeyAugmenter'
  scope: rg
  params: {
    apimName: apimName
    apiNames: azureOpenAIApis.outputs.aoaiApiNames
    consumerNameToClientIdMappings: consumerNameToClientIdMappings
    consumerDemandSubscriptionKeySecrets: apimProductMappings.outputs.consumerResources
  }
}

module aiCentral 'Platform/AICentral/main.bicep' = {
  name: '${deployment().name}-aiCentral'
  scope: rg
  params: {
    location: location
    aspId: consumerHostingPlatform.outputs.aspId
    vnetIntegrationSubnetId: network.outputs.vnetIntegrationSubnetId
    aiCentralAppName: aiCentralAppName
    appServiceDnsZoneId: network.outputs.appServicePrivateDnsZoneId
    peSubnetId: network.outputs.peSubnetId
    cosmosName: cosmos.outputs.cosmosName
    storageAccountName: storage.outputs.storageName
    aiCentralManagedIdentityName: platformKeyVault.outputs.platformManagedIdentityName
  }
}

//Simplification - this isn't technically part of the platform but we are going to deploy a web-app to assist our PromptFlow consumer
module consumerPromptFlow 'SampleConsumer/main.bicep' = {
  name: '${deployment().name}-consumerPromptFlow'
  scope: consumerrg
  params: {
    acrName: consumerHostingPlatform.outputs.acrName
    appInsightsName: monitoring.outputs.appInsightsName
    appServicePlanId: consumerHostingPlatform.outputs.aspId
    vnetIntegrationSubnet: network.outputs.vnetIntegrationSubnetId
    webAppName: webappname
    location: location
    logAnalyticsId: monitoring.outputs.logAnalyticsId
    acrManagedIdentityName: consumerHostingPlatform.outputs.acrPullerManagedIdentityName
    aiCentralHostName: 'https://${aiCentralAppName}.azurewebsites.net'
    kvDnsZoneId: network.outputs.kvPrivateDnsZoneId
    peSubnet: network.outputs.peSubnetId
    azureSearchPrivateDnsZoneId: network.outputs.azureSearchPrivateDnsZoneId
    aiCentralResourceId: aiCentral.outputs.aiCentralResourceId
    platformRg: rg.name
  }
}

module aiCentralConfig 'Platform/AICentral/config.bicep' = {
  name: '${deployment().name}-aiCentralConfig'
  scope: rg
  params: {
    aiCentralAppName: aiCentralAppName
    location: location
    appInsightsName: appInsightsName
    aiGatewayUri: apimFoundation.outputs.apimUri
    consumerNameToAPImSubscriptionSecretMapping: apimProductMappings.outputs.consumerResources
    platformKeyVaultName: platformKeyVault.outputs.kvName
    consumerNameToClientIdMappings: consumerNameToClientIdMappings
    textAnalyticsUri: textAnalytics.outputs.textAnalyticsUri
    cosmosUri: cosmos.outputs.cosmosUri
    queueUri: storage.outputs.queueUri
    textAnalyticsSecretUri: textAnalytics.outputs.textAnalyticsSecretUri
    embeddingsDeploymentName: vectorizerEmbeddingsDeploymentName
    aiCentralUamiClientId: aiCentral.outputs.aiCentralUamiClientId
  }
  dependsOn: [aiCentral]
}

// //try deploy an AI Studio hub / project
module aiStudio 'Platform/AIStudioProject/main.bicep' = {
  name: '${deployment().name}-aiStudio'
  scope: rg
  params: {
    location: location
    aiStudioHubName: '${resourcePrefix}-aishub'
    keyVaultName: platformKeyVault.outputs.kvName
    storageName: storage.outputs.storageName
    acrName: aiStudioAcrName
    azopenaiName: aoais.outputs.aoaiResources[0].resourceName
    aiStudioProjectName: '${resourcePrefix}-aisprj'
    logAnalyticsId: monitoring.outputs.logAnalyticsId
    aiCentralName: aiCentral.outputs.name
    aiSearchName: consumerPromptFlow.outputs.aiSearchName
    aiSearchRg: consumerrg.name
    azureAiStudioUsersGroupObjectId: azureAiStudioUsersGroupObjectId
    appInsightsName: monitoring.outputs.appInsightsName
  }
}

module developerVm './Platform/DeveloperVM/main.bicep' = if (deployDeveloperVm) {
  name: '${deployment().name}-developerVm'
  scope: rg
  params: {
    location: location
    bastionName: '${replace(resourcePrefix, '-', '')}bastion'
    vmName: 'developervm'
    vmSize: 'Standard_D2s_v4'
    vmImage: '2022-datacenter-azure-edition'
    vnetId: network.outputs.vnetId
    vnetSubnetId: network.outputs.peSubnetId
    bastionSubnetId: network.outputs.bastionSubnetId
    vmUser: developerUsername
    vmPassword: developerPassword
  }
}

output GITHUB_ACR_PULL_CLIENT_ID string = consumerHostingPlatform.outputs.ghActionsClientId
