targetScope = 'resourceGroup'

import { AzureOpenAIResourceOutput, AzureOpenAIResource, AzureOpenAIResourcePool } from '../types.bicep'

param aoaiResources AzureOpenAIResourceOutput[]
param aoaiBackendPools AzureOpenAIResourcePool[]
param apimName string

resource apim 'Microsoft.ApiManagement/service@2023-09-01-preview' existing = {
  name: apimName
}

module aoaiServices 'aoaiApimRbac.bicep' = [
  for existingAoaiResource in aoaiResources: {
    name: '${deployment().name}-rbac-${existingAoaiResource.inputName}'
    params: {
      existingAoaiResource: existingAoaiResource
      apimManagedIdentityPrincipalId: apim.identity.principalId
    }
  }
]

module apimBackendsOnAoaiServices 'aoaiBackend.bicep' = [
  for index in range(0, length(aoaiBackendPools)): {
    name: '${deployment().name}-backend-${index}'
    params: {
      existingAoaiResource: aoaiResources[index]
      apimName: apimName
    }
  }
]

module apimBackendPools 'aoaiBackendPool.bicep' = [
  for index in range(0, length(aoaiBackendPools)): {
    name: '${deployment().name}-pool-${index}'
    params: {
      apimName: apimName
      pool: aoaiBackendPools[index]
      backendServices:  [for index in range(0, length(aoaiBackendPools)): apimBackendsOnAoaiServices[index].outputs.backend]
    }
  }
]
