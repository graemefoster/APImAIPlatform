targetScope = 'resourceGroup'

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

param apimName string
param consumerDemands ConsumerDemand[]
param apiNames string[]

module consumer './consumerDemand.bicep' = [
  for consumerDemand in consumerDemands: {
    name: '${deployment().name}-consumer-${consumerDemand.name}'
    params: {
      apimName: apimName
      consumer: consumerDemand
      apiNames: apiNames
    }
  }
]
