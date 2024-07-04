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
param aoaiPools AzureOpenAIResourcePool[]
param deploymentRequirements DeploymentRequirement[]
param mappedDemands MappedConsumerDemand[]
param consumerDemands ConsumerDemand[]
param aoaiResources AzureOpenAIResource[]
param environmentName string = 'dev'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: platformResourceGroup
  location: location
}

var resourcePrefix = '${platformSlug}-${substring(uniqueString(platformResourceGroup, platformSlug, deployment().name), 0, 5)}-'
var vnetName = '${resourcePrefix}-vnet'
var apimName = '${resourcePrefix}-apim'
var appInsightsName = '${resourcePrefix}-appi'
var acrName = replace('${resourcePrefix}-acr', '-', '')
var logAnalyticsWorkspaceName = '${resourcePrefix}-logs'
var deploymentIdentityName = '${resourcePrefix}-uami'

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
        apiSpecUrl: 'https://raw.githubusercontent.com/graemefoster/APImAIPlatform/main/Platform/AOAI/openapi/aoai-24-04-01-preview.json'
        version: '2024-04-01-preview'
      }
    ]
  }
  dependsOn: [azureOpenAIApimBackends]
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
  }
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
    envName: environmentName
  }
}
