targetScope = 'resourceGroup'

import { ConsumerModelAccess, MappedConsumerDemand } from '../types.bicep'
import { ConsumerDemand } from '../../ConsumerRequirements/APIMAIPlatformConsumerRequirements/types.bicep'

param apimName string
param mappedDemands MappedConsumerDemand[]
param consumerDemands ConsumerDemand[]
param apiNames string[]
param environmentName string

module consumer './consumerDemand.bicep' = [
  for idx in range(0, length(mappedDemands)): {
    name: '${deployment().name}-consumer-${consumerDemands[idx].consumerName}'
    params: {
      apimName: apimName
      consumerDemand: consumerDemands[idx]
      apiNames: apiNames
      mappedDemand: filter(mappedDemands, md => md.consumerName == consumerDemands[idx].consumerName)[0]
      environmentName: environmentName
    }
  }
]
