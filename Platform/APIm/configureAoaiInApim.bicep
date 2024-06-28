targetScope = 'resourceGroup'

import { AzureOpenAIResource, AzureOpenAIResourcePool } from '../types.bicep'

param existingAoaiResources AzureOpenAIResource[]
param aoaiBackendPools AzureOpenAIResourcePool[]
param apimName string

resource apim 'Microsoft.ApiManagement/service@2019-12-01' existing = {
  name: apimName
}

module aoaiServices 'aoaiServices.bicep' = [
  for existingAoaiResource in existingAoaiResources: {
    name: '${deployment().name}-rbac-${existingAoaiResource.name}'
    scope: resourceGroup(existingAoaiResource.resourceGroupName)
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
      existingAoaiResource: aoaiServices[index].outputs.aoaiInformation
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
        AzureOpenAIResourceNames: aoaiBackendPools[index].AzureOpenAIResourceNames
        Pools: [for index in range(0, length(aoaiBackendPools)): apimBackendsOnAoaiServices[index].outputs.backend]
      }
    }
  }
]
