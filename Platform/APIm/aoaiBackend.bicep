targetScope = 'resourceGroup'

import { AzureOpenAIResourceOutput, AzureOpenAIBackend } from '../types.bicep'

param existingAoaiResource AzureOpenAIResourceOutput
param apimName string

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimName
}

resource backend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  name: existingAoaiResource.resourceName
  parent: apim
  properties: {
    title: 'Azure OpenAI'
    description: 'Azure OpenAI Backend'
    url: '${existingAoaiResource.endpoint}openai'
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
    circuitBreaker: {
      rules: [
        {
          failureCondition: {
            count: 3
            errorReasons: [
              'Server errors'
            ]
            interval: 'PT1M'
            statusCodeRanges: [
              {
                min: 500
                max: 599
              }
            ]
          }
          name: 'aoaiBreaker'
          tripDuration: 'PT1M'
          acceptRetryAfter: true
        }
      ]
    }
  }
}

output backend AzureOpenAIBackend = {
  aoaiResourceName: existingAoaiResource.resourceName
  backendId: backend.id
}
