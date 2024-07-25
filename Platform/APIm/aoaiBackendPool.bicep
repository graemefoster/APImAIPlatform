targetScope = 'resourceGroup'

import { AzureOpenAIResourcePool, AzureOpenAIBackend, BackendPoolMember } from '../types.bicep'

param backendServices AzureOpenAIBackend[]
param pool AzureOpenAIResourcePool
param apimName string

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimName
}

resource backend 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = {
  name: pool.PoolName
  parent: apim
  properties: {
    title: 'Azure OpenAI Pool'
    description: 'Azure OpenAI Backend Pool'
    type: 'Pool'
    pool: {
      services: [
        for poolMember in pool.AzureOpenAIResources: {
          id: filter(backendServices, item => toLower(item.friendlyName) == toLower(poolMember.name))[0].backendId
          priority: poolMember.priority
          weight: 1
        }
      ]
    }
  }
}
