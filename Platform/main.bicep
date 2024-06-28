targetScope = 'subscription'

import {AzureOpenAIBackend, AzureOpenAIResource, AzureOpenAIResourcePool, ConsumerModelAccess, DeploymentRequirement, ConsumerDemand } from './types.bicep'

type Configuration = {
  apimName: string
  location: string
  platformResourceGroup: string
  existingAoaiResources: AzureOpenAIResource[]
  azureOpenAiPools: AzureOpenAIResourcePool[]
}

param platformResourceGroup string
param location string
param apimName string
param appInsightsResourceGroup string
param appInsightsName string
param logAnalyticsWorkspaceResourceGroup string
param logAnalyticsWorkspaceName string
param aoaiPools AzureOpenAIResourcePool[]
param deploymentRequirements DeploymentRequirement[]
param consumerDemands ConsumerDemand[]

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: platformResourceGroup
  location: location
}

module apimFoundation 'APIm/apim.bicep' = {
  name: '${deployment().name}-apim'
  scope: rg
  params: {
    apimName: apimName
    appInsightsResourceGroup: appInsightsResourceGroup
    appInsightsName: appInsightsName
    logAnalyticsWorkspaceResourceGroup: logAnalyticsWorkspaceResourceGroup
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
}

// Consider cross subscription here. Sometimes we need to create more AOAI resource in other subscriptions.
// As long as the tenant is the same we can still use Entra to connect from APIm to AOAI.
module azureOpenAIApimBackends 'APIm/configureAoaiInApim.bicep' = {
  name: '${deployment().name}-aoaiBackends'
  scope: rg
  params: {
    apimName: apimName
    existingAoaiResources: existingAoaiResources
    aoaiBackendPools: aoaiPools
  }
}

module azureOpenAIApis 'APIm/aoaiapis.bicep' = {
  name: '${deployment().name}-aoaiApi'
  scope: rg
  params: {
    apimName: apimName
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
}

module azureOpenAiDeployments 'AOAI/aoaideployments.bicep' = {
  name: '${deployment().name}-aoaiDeployments'
  params: {
    deploymentRequirements: deploymentRequirements
  }
}

module apimProductMappings 'Consumers/consumerDemands.bicep' = {
  name: '${deployment().name}-consumerDemands'
  scope: rg
  params: {
    apimName: apimName
    consumerDemands: consumerDemands
    apiNames: azureOpenAIApis.outputs.aoaiApiNames
  }
}
