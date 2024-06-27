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

type ApiVersion = {
  version: string
  apiSpecUrl: string
}


type AzureOpenAIResourceOutput = {
  resourceId: string
  resourceGroupName: string
  resourceName: string
  endpoint: string
}

type AzureOpenAIBackend = {
  aoaiResourceName: string
  backendId: string
}

type AzureOpenAIResourcePool = {
  PoolName: string
  AzureOpenAIResourceNames: string[]
  Pools: AzureOpenAIBackend[]
}


type ConsumerModelAccess = {
  modelName: string
  expectedThroughputThousandsOfTokensPerMinute: int
  platformTeamDeploymentMapping: string
  platformTeamPoolMapping: string
}

type ConsumerDemand = {
  name: string
  consumerName: string
  requirements: ConsumerModelAccess[]
}

