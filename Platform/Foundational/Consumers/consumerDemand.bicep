targetScope = 'resourceGroup'

type ConsumerModelAccess = {
  modelName: string
  expectedThroughputThousandsOfTokensPerMinute: int
  platformTeamDeploymentMapping: string
  platformTeamPoolMapping: string
  outsideDeploymentName: string
}

type ConsumerDemand = {
  name: string
  consumerName: string
  requirements: ConsumerModelAccess[]
}

param apimName string
param apiNames string[]
param consumer ConsumerDemand

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimName
}

resource apimProduct 'Microsoft.ApiManagement/service/products@2023-05-01-preview' = {
  name: 'product-${consumer.name}'
  parent: apim
  properties: {
    displayName: consumer.consumerName
    description: 'Product for consumer ${consumer.consumerName}'
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

resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' = {
  name: 'subscription-${consumer.name}'
  parent: apim
  properties: {
    displayName: 'Subscription for ${consumer.consumerName}'
    scope: '/products/${apimProduct.name}'
  }
}

//build up the policy for the Product. Start with rewrite-url to make the inside deployment correct, but keep a stable outside deployment
var requirementsString = join(
  map(consumer.requirements, r => 'dictionary["${r.outsideDeploymentName}"] = "${r.platformTeamDeploymentMapping}";'),
  '\n'
)
var poolMapString = join(
  map(consumer.requirements, r => 'dictionary["${r.outsideDeploymentName}"] = "${r.platformTeamPoolMapping}";'),
  '\n'
)
var policyXml = replace(loadTextContent('./product-policy.xml'), '{policy-map}', requirementsString)
var finalPolicyXml = replace(policyXml, '{policy-pool-map}', poolMapString)

resource productFragment 'Microsoft.ApiManagement/service/products/policies@2023-05-01-preview' = {
  parent: apimProduct
  name: 'policy'
  properties: {
    format: 'xml'
    value: finalPolicyXml
  }
}

