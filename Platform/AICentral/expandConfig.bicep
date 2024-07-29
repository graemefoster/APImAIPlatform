import { ConsumerNameToClientIdMapping } from '../types.bicep'

param parentIndex int
param input ConsumerNameToClientIdMapping

var output = [for idx in range(0, length(input.entraClientIds)): {
  name: 'AICentral__ClaimsToKeys__${parentIndex}__ClaimValues__${idx}'
  value: input.entraClientIds[idx]
}]

output result array = output
