targetScope = 'resourceGroup'

type AzureOpenAIBackend = {
  aoaiResourceName: string
  backendId: string
}

type AzureOpenAIResourcePool = {
  PoolName: string
  AzureOpenAIResourceNames: string[]
  Pools: AzureOpenAIBackend[]
}

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
          id: filter(pool.Pools, item => toLower(item.aoaiResourceName) == toLower(aoaiName))[0].backendId
        }
      ]
    }
  }
}
