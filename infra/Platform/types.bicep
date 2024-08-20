type deploymentType = 'PTU' | 'PAYG' | 'GlobalStandard' | 'GlobalBatch'

@export()
type DeploymentRequirement = {
  aoaiName: string
  deploymentName: string
  model: string
  modelVersion: string
  thousandsOfTokensPerMinute: int
  deploymentType: deploymentType
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
  location: string
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
  friendlyName: string
  aoaiResourceName: string
  backendId: string
}

@export()
type AzureOpenAIResourcePool = {
  poolName: string
  azureOpenAIResources: BackendPoolMember[]
}

@export()
type MappedConsumerDemand = {
  consumerName: string
  requirements: ConsumerModelAccess[]
}

@export()
type ConsumerDemandOutput = {
  consumerName: string
  secretUri: string
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

@export()
type ConsumerNameToApimSubscriptionKey = {
  consumerName: string
  secretUri: string
}

@export()
type ConsumerNameToClientIdMapping = {
  consumerName: string
  entraClientIds: string[]
}

@export()
type BackendPoolMember = {
  name: string
  priority: int
}


@export()
type ConsumerDemand = {
  consumerName: string
  requestName: string
  contactEmail: string
  costCentre: string
  models: ConsumerDemandModel[]
  constantAppIdIdentifiers: AppIdentifier[]
}

@export()
type AppIdentifier = {
  name: string
  appId: string
}

@export() 
type ModelContentSafety = {
  prompt: PromptModelContentSafety
  response: ResponseModelContentSafety
}

@export()
type PromptModelContentSafety = {
  abuse: string
}
@export()
type ResponseModelContentSafety = {
  abuse: string
}

