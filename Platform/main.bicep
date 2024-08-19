targetScope = 'subscription'

import {
  AzureOpenAIBackend
  AzureOpenAIResource
  AzureOpenAIResourcePool
  ConsumerModelAccess
  DeploymentRequirement
  MappedConsumerDemand
} from './types.bicep'

import {
  ConsumerDemand
} from '../ConsumerRequirements/APIMAIPlatformConsumerRequirements/types.bicep'

param platformResourceGroup string
param platformSlug string
param apimPublisherEmail string
param apimPublisherName string
param ghRepo string
param ghUsername string
param location string
param tenantId string
param aoaiPools AzureOpenAIResourcePool[]
param deploymentRequirements DeploymentRequirement[]
param mappedDemands MappedConsumerDemand[]
param consumerDemands ConsumerDemand[]
param aoaiResources AzureOpenAIResource[]
param environmentName string = 'dev'
param vectorizerEmbeddingsDeploymentName string

//we grant some additional permissions to this group to enable AI Studio to work
param azureAiStudioUsersGroupObjectId string

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

module monitoring 'Foundation/monitoring.bicep' = {
  name: '${deployment().name}-monitoring'
  scope: rg
  params: {
    appInsightsName: appInsightsName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    location: location
  }
}

module network 'Foundation/networks.bicep' = {
  name: '${deployment().name}-network'
  scope: rg
  params: {
    vnetName: vnetName
  }
}

module platformKeyVault 'Foundation/kv.bicep' = {
  name: '${deployment().name}-platformkv'
  scope: rg
  params: {
    keyvaultName: platformKeyVaultName
    kvDnsZoneId: network.outputs.kvPrivateDnsZoneId
    peSubnetId: network.outputs.peSubnetId
    location: location
  }
}

module storage 'Foundation/storage.bicep' = {
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

module cosmos 'Audit/main.bicep' = {
  name: '${deployment().name}-cosmos'
  scope: rg
  params: {
    peSubnetId: network.outputs.peSubnetId
    cosmosName: cosmosName
    cosmosPrivateDnsZoneId: network.outputs.cosmosPrivateDnsZoneId
    location: location
  }
}

module textAnalytics 'Audit/text-analytics.bicep' = {
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

module aoais 'AOAI/aoais.bicep' = {
  name: '${deployment().name}-aoais'
  scope: rg
  params: {
    aoaiNames: aoaiResources
    location: location
    privateDnsZoneId: network.outputs.openAiPrivateDnsZoneId
    privateEndpointSubnetId: network.outputs.peSubnetId
    resourcePrefix: resourcePrefix
    logAnalyticsId: monitoring.outputs.logAnalyticsId
  }
}

module azureOpenAiDeployments 'AOAI/aoaideployments.bicep' = {
  name: '${deployment().name}-aoaiDeployments'
  scope: rg
  params: {
    deploymentRequirements: deploymentRequirements
    aoaiOutputs: aoais.outputs.aoaiResources
  }
  dependsOn: [aoais]
}

module apimFoundation 'APIm/apim.bicep' = {
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
  }
}

// Consider cross subscription here. Sometimes we need to create more AOAI resource in other subscriptions.
// As long as the tenant is the same we can still use Entra to connect from APIm to AOAI.
module azureOpenAIApimBackends 'APIm/configureAoaiInApim.bicep' = {
  name: '${deployment().name}-aoaiBackends'
  scope: rg
  params: {
    apimName: apimFoundation.outputs.apimName
    aoaiResources: aoais.outputs.aoaiResources
    aoaiBackendPools: aoaiPools
  }
}

module azureOpenAIApis 'APIm/aoaiapis.bicep' = {
  name: '${deployment().name}-aoaiApi'
  scope: rg
  params: {
    apimName: apimFoundation.outputs.apimName
    azureOpenAiApis: [
      {
        apiSpecUrl: 'https://raw.githubusercontent.com/graemefoster/APImAIPlatform/main/Platform/AOAI/openapi/aoai-2022-12-01.json'
        version: '2022-12-01'
      }
      {
        //used by some bits of Promptflow (the index lookup tool) as of July 2024
        apiSpecUrl: 'https://raw.githubusercontent.com/graemefoster/APImAIPlatform/main/Platform/AOAI/openapi/aoai-2023-03-15-preview.json'
        version: '2023-03-15-preview'
      }
      {
        //used by PromptFlow as of July 2024
        apiSpecUrl: 'https://raw.githubusercontent.com/graemefoster/APImAIPlatform/main/Platform/AOAI/openapi/aoai-2023-07-01-preview.json'
        version: '2023-07-01-preview'
      }
      {
        apiSpecUrl: 'https://raw.githubusercontent.com/graemefoster/APImAIPlatform/main/Platform/AOAI/openapi/aoai-24-04-01-preview.json'
        version: '2024-04-01-preview'
      }
    ]
  }
  dependsOn: [azureOpenAIApimBackends]
}

module consumerHostingPlatform './ConsumerOrchestratorHost/main.bicep' = {
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

module apimProductMappings 'Consumers/consumerDemands.bicep' = {
  name: '${deployment().name}-consumerDemands'
  scope: rg
  params: {
    apimName: apimFoundation.outputs.apimName
    consumerDemands: consumerDemands
    mappedDemands: mappedDemands
    apiNames: azureOpenAIApis.outputs.aoaiApiNames
    environmentName: environmentName
    platformKeyVaultName: platformKeyVaultName
    consumerNameToClientIdMappings: consumerNameToClientIdMappings
  }
}

module aiCentral './AICentral/main.bicep' = {
  name: '${deployment().name}-aiCentral'
  scope: rg
  params: {
    location: location
    aspId: consumerHostingPlatform.outputs.aspId
    vnetIntegrationSubnetId: network.outputs.vnetIntegrationSubnetId
    aiCentralAppName: aiCentralAppName
    platformKeyVaultName: platformKeyVault.outputs.kvName
    appServiceDnsZoneId: network.outputs.appServicePrivateDnsZoneId
    peSubnetId: network.outputs.peSubnetId
    cosmosName: cosmos.outputs.cosmosName
    storageAccountName: storage.outputs.storageName
  }
}

//Simplification - this isn't technically part of the platform but we are going to deploy a web-app to assist our PromptFlow consumer
module consumerPromptFlow '../Consumers/PromptFlow/main.bicep' = {
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

var consumerNameToClientIdMappings = [
  {
    consumerName: 'consumer-1'
    entraClientIds: [
      consumerPromptFlow.outputs.promptFlowAppIdentityId
    ]
  }
  {
    consumerName: 'aistudio'
    //machine learning services app-id and the azure CLI to facilitate local-dev.
    entraClientIds: ['18a66f5f-dbdf-4c17-9dd7-1634712a9cbe', '04b07795-8ddb-461a-bbee-02f9e1bf7b46'] 
  }
]

module aiCentralConfig './AICentral/config.bicep' = {
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

//try deploy an AI Studio hub / project
// module aiStudio 'AIStudioProject/main.bicep' = {
//   name: '${deployment().name}-aiStudio'
//   scope: rg
//   params: {
//     location: location
//     aiStudioHubName: '${resourcePrefix}-aishub'
//     keyVaultName: platformKeyVault.outputs.kvName
//     storageName: storage.outputs.storageName
//     acrName: aiStudioAcrName
//     azopenaiName: aoais.outputs.aoaiResources[0].resourceName
//     aiStudioProjectName: '${resourcePrefix}-aisprj3'
//     logAnalyticsId: monitoring.outputs.logAnalyticsId
//     aiCentralName: aiCentral.outputs.name
//     aiSearchName: consumerPromptFlow.outputs.aiSearchName
//     aiSearchRg: consumerrg.name
//     azureAiStudioUsersGroupObjectId: azureAiStudioUsersGroupObjectId
//     appInsightsName: monitoring.outputs.appInsightsName
//   }
// }

output GITHUB_ACR_PULL_CLIENT_ID string = consumerHostingPlatform.outputs.ghActionsClientId
