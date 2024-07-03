@export()
type DeploymentRequirement = {
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
  id: string
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
type MappedConsumerDemand = {
  consumerName: string
  requirements: ConsumerModelAccess[]
}

@export()
type ConsumerDemandEnvironments = {
  dev: ConsumerDemandEnvironment
  test: ConsumerDemandEnvironment
  prod: ConsumerDemandEnvironment
}

@export()
type ConsumerDemandEnvironment = {
  thousandsOfTokens: int
  deployAt: string
}

@export()
type ConsumerDemandModel = {
  id: string
  modelName: string
  environments: ConsumerDemandEnvironment
}
