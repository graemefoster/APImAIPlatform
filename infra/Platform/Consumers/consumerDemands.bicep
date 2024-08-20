targetScope = 'resourceGroup'

import { ConsumerModelAccess, MappedConsumerDemand, ConsumerDemandOutput, ConsumerNameToClientIdMapping, ConsumerDemand  } from '../types.bicep'

param apimName string
param mappedDemands MappedConsumerDemand[]
param consumerDemands ConsumerDemand[]
param apiNames string[]
param environmentName string
param platformKeyVaultName string
param consumerNameToClientIdMappings ConsumerNameToClientIdMapping[]

module consumer './consumerDemand.bicep' = [
  for idx in range(0, length(mappedDemands)): {
    name: '${deployment().name}-consumer-${consumerDemands[idx].consumerName}'
    params: {
      apimName: apimName
      consumerDemand: consumerDemands[idx]
      apiNames: apiNames
      mappedDemand: filter(mappedDemands, md => md.consumerName == consumerDemands[idx].consumerName)[0]
      environmentName: environmentName
      platformKeyVaultName: platformKeyVaultName
      consumerAppIds: filter(consumerNameToClientIdMappings, item => item.consumerName == consumerDemands[idx].consumerName)[0].entraClientIds
    }
  }
]

output consumerResources ConsumerDemandOutput[] = [
  for idx in range(0, length(consumerDemands)): {
    consumerName: consumerDemands[idx].consumerName
    secretUri: consumer[idx].outputs.subscriptionKeySecretUri
  }
]
