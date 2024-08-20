import {
  AzureOpenAIBackend
  AzureOpenAIResource
  AzureOpenAIResourcePool
  ConsumerModelAccess
  DeploymentRequirement
  MappedConsumerDemand
  ApiVersion
  ConsumerDemand
} from 'Platform/types.bicep'

var json = loadJsonContent('./platform.json')


output aoaiResources AzureOpenAIResource[] = json.aoaiServices
output aoaiDeployments DeploymentRequirement[] = json.deployments
output apimBackendPools AzureOpenAIResourcePool[] = json.pools
output apiVersions ApiVersion[] = json.apiVersions
output consumerDemands ConsumerDemand[] = json.consumerDemands
output platformMappedConsumerDemands MappedConsumerDemand[] = json.mappedDemands
