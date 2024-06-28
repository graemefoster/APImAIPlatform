param apimName string

type ApiVersion = {
  version: string
  apiSpecUrl: string
}

param azureOpenAiApis ApiVersion[] = []

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimName
}

resource aoaiApiVersionSet 'Microsoft.ApiManagement/service/apiVersionSets@2023-05-01-preview' = {
  name: 'aoai-version-set'
  parent: apim
  properties: {
    displayName: 'Azure OpenAI'
    description: 'Azure OpenAI Version Set'
    versioningScheme: 'Query'
    versionQueryName: 'api-version'
  }
}

resource aoaiApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = [
  for apiInfo in azureOpenAiApis: {
    name: 'AzureOpenAI-${apiInfo.version}'
    parent: apim
    properties: {
      displayName: 'Azure OpenAI'
      description: 'Azure OpenAI API'
      serviceUrl: 'https://unused.local'
      path: '/openai/'
      format: 'openapi-link'
      type: 'http'
      apiType: 'http'
      value: apiInfo.apiSpecUrl
      apiVersion: apiInfo.version
      apiVersionSetId: aoaiApiVersionSet.id
      subscriptionRequired: true
      subscriptionKeyParameterNames: {
        header: 'api-key'
        query: 'api-key'
      }
    }
  }
]

var policy = loadTextContent('./aoai-policy.xml')

resource productFragment 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = [
  for index in range(0, length(azureOpenAiApis)): {
    parent: aoaiApi[index]
    name: 'policy'
    properties: {
      format: 'rawxml'
      value: policy
    }
  }
]

output aoaiApiIds array = [for i in range(0, length(azureOpenAiApis)): aoaiApi[i].id]
output aoaiApiNames array = [for i in range(0, length(azureOpenAiApis)): aoaiApi[i].name]
