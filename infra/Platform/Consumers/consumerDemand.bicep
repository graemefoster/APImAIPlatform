targetScope = 'resourceGroup'

import { ConsumerModelAccess, MappedConsumerDemand, ConsumerDemand  } from '../types.bicep'

param apimName string
param apiNames string[]
param mappedDemand MappedConsumerDemand
param consumerDemand ConsumerDemand
param environmentName string
param platformKeyVaultName string
param consumerAppIds string[]
param platformUamiClientId string

param now string = utcNow('s')

resource platformKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: platformKeyVaultName
}

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimName
}

resource apimProduct 'Microsoft.ApiManagement/service/products@2023-05-01-preview' = if(consumerDemand.models[0].environments[environmentName].deployAt < now) {
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
      name: 'apiLink-${mappedDemand.consumerName}${api}'
      properties: {
        apiId: resourceId('Microsoft.ApiManagement/service/apis', apimName, api)
      }
    }
  ]
}

resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' = {
  name: 'subscription-${mappedDemand.consumerName}'
  parent: apim
  properties: {
    scope: '/products/${apimProduct.name}'
    displayName: 'Subscription for ${mappedDemand.consumerName}'
    state: 'active'
  }
}

//These are not secrets - they just enable us to target policy for a consumer. The authentication / authorisation is done by a JWT.
resource platformSubscriptionKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'platformSubscriptionKey-${mappedDemand.consumerName}'
  parent: platformKeyVault
  properties: {
    contentType: 'text/plan'
    value: apimSubscription.listSecrets().primaryKey
  }
}

resource apimNamedValueForKey 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  name: 'subkey-${mappedDemand.consumerName}'
  parent: apim
  properties: {
    displayName: 'subkey-${mappedDemand.consumerName}'
    keyVault: {
      secretIdentifier: platformSubscriptionKey.properties.secretUri
      identityClientId: platformUamiClientId
    }
    secret: true
  }
}

//build up the policy for the Product. Start with rewrite-url to make the inside deployment correct, but keep a stable outside deployment
var requirementsString = join(
  map(
    mappedDemand.requirements,
    r => 'if (incomingDeploymentId == "${r.outsideDeploymentName}") { newId = "${r.platformTeamDeploymentMapping}"; }'
  ),
  '\n'
)
var poolMapString = join(
  map(
    mappedDemand.requirements,
    r => 'if (incomingDeploymentId == "${r.outsideDeploymentName}") { newId = "${r.platformTeamPoolMapping}"; }'
  ),
  '\n'
)
var poolMapSizeString = join(
  map(
    mappedDemand.requirements,
    r => 'if (incomingDeploymentId == "${r.outsideDeploymentName}") { poolSize = ${length(apiNames)}; }'
  ),
  '\n'
)

var tokenRateLimiting = join(
  map(
    mappedDemand.requirements,
    r =>
      '<when condition="@(context.Request.MatchedParameters["deployment-id"] == "${r.outsideDeploymentName}")">\n<azure-openai-token-limit tokens-per-minute="${filter(consumerDemand.models, cd => r.outsideDeploymentName == cd.deploymentName)[0].environments[environmentName].thousandsOfTokens * 1000}" estimate-prompt-tokens="true" tokens-consumed-header-name="consumed-tokens" remaining-tokens-header-name="remaining-tokens" counter-key="${r.outsideDeploymentName}" />\n</when>'
  ),
  '\n'
)
var allowedAppIds = join(map(consumerAppIds, appId => '<application-id>${appId}</application-id>'), '')
var policyXml = replace(loadTextContent('./product-policy.xml'), '{policy-map}', requirementsString)
var policyXml2 = replace(policyXml, '{policy-pool-map}', poolMapString)
var policyXml3 = replace(policyXml2, '{applicationIds}', allowedAppIds)
var policyXml4 = replace(policyXml3, '{policy-pool-size-map}', poolMapSizeString)
var finalPolicyXml = replace(policyXml4, '{rate-limiting-section}', tokenRateLimiting)

resource productFragment 'Microsoft.ApiManagement/service/products/policies@2023-05-01-preview' = {
  parent: apimProduct
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: finalPolicyXml
  }
}

output conasumerName string = consumerDemand.consumerName
output subscriptionKeySecretUri string = platformSubscriptionKey.properties.secretUri
output subscriptionKeyNamedValue string = apimNamedValueForKey.properties.displayName
