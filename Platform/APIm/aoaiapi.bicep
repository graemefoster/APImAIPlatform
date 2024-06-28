import { ApiVersion } from '../types.bicep'

param apimName string
param apiInfo ApiVersion
param versionSetName string

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimName
}

resource apimAppInsightsLogger 'Microsoft.ApiManagement/service/loggers@2023-05-01-preview' existing = {
  parent: apim
  name: 'applicationInsights'
}

resource aoaiApiVersionSet 'Microsoft.ApiManagement/service/apiVersionSets@2023-05-01-preview' existing = {
  name: versionSetName
}

resource aoaiApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
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

  resource diagnostics 'diagnostics@2023-05-01-preview' = {
    name: 'diagnostics'
    properties: {
      loggerId: apimAppInsightsLogger.id
      metrics: true
    }
  }

  resource productFragment 'policies@2023-05-01-preview' = {
    name: 'policy'
    properties: {
      format: 'rawxml'
      value: policy
    }
  }
}

var policy = loadTextContent('./aoai-policy.xml')

output aoaiApiId string = aoaiApi.id
output aoaiApiName string = aoaiApi.name
