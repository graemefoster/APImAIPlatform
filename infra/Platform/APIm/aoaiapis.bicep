param apimName string

import { ApiVersion } from '../types.bicep'

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

module aoaiApi './aoaiapi.bicep' = [
  for apiInfo in azureOpenAiApis: {
    name: '${deployment().name}-api-${apiInfo.version}'
    params: {
      apimName: apimName
      apiInfo: apiInfo
      versionSetName: aoaiApiVersionSet.name
    }
  }
]

output aoaiApiIds array = [for i in range(0, length(azureOpenAiApis)): aoaiApi[i].outputs.aoaiApiId]
output aoaiApiNames array = [for i in range(0, length(azureOpenAiApis)): aoaiApi[i].outputs.aoaiApiName]
