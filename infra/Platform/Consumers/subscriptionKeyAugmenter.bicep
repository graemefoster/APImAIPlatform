targetScope = 'resourceGroup'

import { ConsumerNameToClientIdMapping, ConsumerDemandOutput } from '../types.bicep'

param apimName string
param apiNames string[]
param consumerNameToClientIdMappings ConsumerNameToClientIdMapping[]
param consumerDemandSubscriptionKeySecrets ConsumerDemandOutput[]

resource apim 'Microsoft.ApiManagement/service@2023-09-01-preview' existing = {
  name: apimName
}

resource subscriptionKeyAugmentingProduct 'Microsoft.ApiManagement/service/products@2023-09-01-preview' = {
  name: 'AzureOpenAI'
  parent: apim
  properties: {
    displayName: 'Azure OpenAI Subscription Key Augmenting Product'
    description: 'Product for augmenting subscription keys to invoke product behaviour.'
    subscriptionRequired: false
  }

  resource apiLink 'apiLinks@2023-05-01-preview' = [
    for api in apiNames: {
      name: 'apiLink-subkey-${api}'
      properties: {
        apiId: resourceId('Microsoft.ApiManagement/service/apis', apimName, api)
      }
    }
  ]
}

var subscriptionKeyMap = join(
  map(
    consumerNameToClientIdMappings,
    r =>
      'if ((new string[] { ${join(map(r.entraClientIds, e => '"${e}"'), ',')} }).Contains(incomingAppId)) { return "{{${filter(consumerDemandSubscriptionKeySecrets, x=>x.consumerName == r.consumerName)[0].apimNamedValue}}}"; }'
  ),
  '\n'
)

var policyXml = replace(loadTextContent('./subscriptionKeyAugmenterPolicy.xml'), '{subscription-key-map}', subscriptionKeyMap)

resource productFragment 'Microsoft.ApiManagement/service/products/policies@2023-05-01-preview' = {
  parent: subscriptionKeyAugmentingProduct
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: policyXml
  }
}
