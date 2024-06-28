targetScope = 'resourceGroup'

import { AzureOpenAIResourcePool, AzureOpenAIBackend } from '../types.bicep'

param backendServices AzureOpenAIBackend[]
param pool AzureOpenAIResourcePool
param apimName string

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimName
}

resource backend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  name: pool.PoolName
  parent: apim
  properties: {
    title: 'Azure OpenAI Pool'
    description: 'Azure OpenAI Backend Pool'
    type: 'Pool'
    pool: {
      services: [
        for aoaiName in pool.AzureOpenAIResourceNames: {
          id: filter(backendServices, item => toLower(item.aoaiResourceName) == toLower(aoaiName))[0].backendId
        }
      ]
    }
  }
}
