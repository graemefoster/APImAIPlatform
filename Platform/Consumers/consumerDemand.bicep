targetScope = 'resourceGroup'

import { ConsumerModelAccess, MappedConsumerDemand } from '../types.bicep'
import { ConsumerDemand } from '../../ConsumerRequirements/APIMAIPlatformConsumerRequirements/types.bicep'

param apimName string
param apiNames string[]
param mappedDemand MappedConsumerDemand
param consumerDemand ConsumerDemand
param environmentName string

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimName
}

resource apimProduct 'Microsoft.ApiManagement/service/products@2023-05-01-preview' = {
  name: 'product-${mappedDemand.consumerName}'
  parent: apim
  properties: {
    displayName: mappedDemand.consumerName
    description: 'Product for consumer ${mappedDemand.consumerName}'
    approvalRequired: false
    subscriptionRequired: true
    subscriptionsLimit: 1
    state: 'published'
  }

  resource apiLink 'apiLinks@2023-05-01-preview' = [
    for api in apiNames: {
      name: 'apiLink-${api}'
      properties: {
        apiId: resourceId('Microsoft.ApiManagement/service/apis', apimName, api)
      }
    }
  ]
}

//build up the policy for the Product. Start with rewrite-url to make the inside deployment correct, but keep a stable outside deployment
var requirementsString = join(
  map(mappedDemand.requirements, r => 'dictionary["${r.outsideDeploymentName}"] = "${r.platformTeamDeploymentMapping}";'),
  '\n'
)
var poolMapString = join(
  map(mappedDemand.requirements, r => 'dictionary["${r.outsideDeploymentName}"] = "${r.platformTeamPoolMapping}";'),
  '\n'
)

var tokenRateLimiting = join(
  map(mappedDemand.requirements, r => '<when condition="@(context.Request.MatchedParameters["deployment-id"] == "${r.outsideDeploymentName}")">\n<azure-openai-token-limit tokens-per-minute="${filter(consumerDemand.models, cd => r.id == cd.id)[0].environments[environmentName].thousandsOfTokens * 1000}" estimate-prompt-tokens="true" tokens-consumed-header-name="consumed-tokens" remaining-tokens-header-name="remaining-tokens" counter-key="${r.outsideDeploymentName}" />\n</when>'),
  '\n'
)
var policyXml = replace(loadTextContent('./product-policy.xml'), '{policy-map}', requirementsString)
var policyXml2 = replace(policyXml, '{policy-pool-map}', poolMapString)
var finalPolicyXml = replace(policyXml2, '{rate-limiting-section}', tokenRateLimiting)

resource productFragment 'Microsoft.ApiManagement/service/products/policies@2023-05-01-preview' = {
  parent: apimProduct
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: finalPolicyXml
  }
}

