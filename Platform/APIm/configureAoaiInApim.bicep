targetScope = 'resourceGroup'

import { AzureOpenAIResourceOutput, AzureOpenAIResource, AzureOpenAIResourcePool } from '../types.bicep'

param existingAoaiResources AzureOpenAIResourceOutput[]
param aoaiBackendPools AzureOpenAIResourcePool[]
param apimName string

resource apim 'Microsoft.ApiManagement/service@2019-12-01' existing = {
  name: apimName
}

module aoaiServices 'aoaiApimRbac.bicep' = [
  for existingAoaiResource in existingAoaiResources: {
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
      existingAoaiResource: existingAoaiResources[index]
      apimName: apimName
    }
  }
]

module apimBackendPools 'aoaiBackendPool.bicep' = [
  for index in range(0, length(aoaiBackendPools)): {
    name: '${deployment().name}-pool-${index}'
    params: {
      apimName: apimName
      pool: {
        PoolName: aoaiBackendPools[index].PoolName
        AzureOpenAIResourceNames: map(
          aoaiBackendPools[index].AzureOpenAIResourceNames, 
          resourceName => filter(existingAoaiResources, e => e.inputName == resourceName)[0].resourceName)
      }
      backendServices:  [for index in range(0, length(aoaiBackendPools)): apimBackendsOnAoaiServices[index].outputs.backend]
    }
  }
]
