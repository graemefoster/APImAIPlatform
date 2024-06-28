targetScope = 'resourceGroup'

import { ConsumerModelAccess, ConsumerDemand } from '../types.bicep'

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
