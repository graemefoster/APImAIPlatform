targetScope = 'resourceGroup'

type AzureOpenAIResourceOutput = {
  resourceName: string
  resourceId: string
  endpoint: string
}

type AzureOpenAIBackend = {
  aoaiResourceName: string
  backendId: string
}

param existingAoaiResource AzureOpenAIResourceOutput
param apimName string

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimName
}

resource backend 'Microsoft.ApiManagement/service/backends@2022-08-01' = {
  name: 'aoai-${existingAoaiResource.resourceName}'
  parent: apim
  properties: {
    title: 'Azure OpenAI'
    description: 'Azure OpenAI Backend'
    url: '${existingAoaiResource.endpoint}/openai'
    protocol: 'http'
  }
}

output backend AzureOpenAIBackend = {
  aoaiResourceName: existingAoaiResource.resourceName
  backendId: backend.id
}
