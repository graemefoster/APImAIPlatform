targetScope = 'subscription'

type AzureOpenAIResource = {
  resourceGroupName: string
  name: string
}

type AzureOpenAIResourcePool = {
  PoolName: string
  AzureOpenAIResourceNames: string[]
}

type Configuration = {
  apimName: string
  location: string
  platformResourceGroup: string
  existingAoaiResources: AzureOpenAIResource[]
  azureOpenAiPools: AzureOpenAIResourcePool[]
}

type ConsumerModelAccess = {
  modelName: string
  expectedThroughputThousandsOfTokensPerMinute: int
  platformTeamDeploymentMapping: string
  platformTeamPoolMapping: string
  outsideDeploymentName: string
}

type DeploymentRequirement = {
  aoaiResourceGroupName: string
  aoaiName: string
  name: string
  deploymentName: string
  model: string
  modelVersion: string
  thousandsOfTokensPerMinute: int
  isPTU: bool
  enableDynamicQuota: bool
}

type ConsumerDemand = {
  name: string
  consumerName: string
  requirements: ConsumerModelAccess[]
}

param platformResourceGroup string
param location string
param apimName string
param existingAoaiResources AzureOpenAIResource[]
param aoaiPools AzureOpenAIResourcePool[]
param deploymentRequirements DeploymentRequirement[]
param consumerDemands ConsumerDemand[]

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: platformResourceGroup
  location: location
}

module apimFoundation 'Foundational/APIm/apim.bicep' = {
  name: '${deployment().name}-apim'
  scope: rg
  params: {
    apimName: apimName
  }
}

// Consider cross subscription here. Sometimes we need to create more AOAI resource in other subscriptions.
// As long as the tenant is the same we can still use Entra to connect from APIm to AOAI.
module azureOpenAIApimBackends 'Foundational/APIm/configureAoaiInApim.bicep' = {
  name: '${deployment().name}-aoaiBackends'
  scope: rg
  params: {
    apimName: apimName
    existingAoaiResources: existingAoaiResources
    aoaiBackendPools: aoaiPools
  }
}

module azureOpenAIApis 'Foundational/APIm/aoaiapi.bicep' = {
  name: '${deployment().name}-aoaiApi'
  scope: rg
  params: {
    apimName: apimName
    azureOpenAiApis: [
      {
        apiSpecUrl: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-02-01/inference.json'
        version: '2024-02-01'
      }
      {
        apiSpecUrl: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/preview/2024-04-01-preview/inference.json'
        version: '2024-04-01-preview'
      }
    ]
  }
}

module azureOpenAiDeployments './Foundational/AOAI/aoaideployments.bicep' = {
  name: '${deployment().name}-aoaiDeployments'
  params: {
    deploymentRequirements: deploymentRequirements
  }
}

module apimProductMappings './Foundational/Consumers/consumerDemands.bicep' = {
  name: '${deployment().name}-consumerDemands'
  scope: rg
  params: {
    apimName: apimName
    consumerDemands: consumerDemands
    apiNames: azureOpenAIApis.outputs.aoaiApiNames
  }
}
