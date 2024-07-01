@export()
type DeploymentRequirement = {
  aoaiResourceGroupName: string
  aoaiName: string
  deploymentName: string
  model: string
  modelVersion: string
  thousandsOfTokensPerMinute: int
  isPTU: bool
  enableDynamicQuota: bool
}

@export()
type ConsumerModelAccess = {
  modelName: string
  expectedThroughputThousandsOfTokensPerMinute: int
  platformTeamDeploymentMapping: string
  platformTeamPoolMapping: string
  outsideDeploymentName: string
}

@export()
type ApiVersion = {
  version: string
  apiSpecUrl: string
}

@export()
type AzureOpenAIResource = {
  name: string
}

@export()
type AzureOpenAIResourceOutput = {
  resourceId: string
  resourceGroupName: string
  inputName: string
  resourceName: string //we prefix / add slug, etc
  endpoint: string
}

@export()
type AzureOpenAIBackend = {
  aoaiResourceName: string
  backendId: string
}

@export()
type AzureOpenAIResourcePool = {
  PoolName: string
  AzureOpenAIResourceNames: string[]
}


@export()
type ConsumerDemand = {
  name: string
  consumerName: string
  requirements: ConsumerModelAccess[]
}
