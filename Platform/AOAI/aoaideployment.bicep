targetScope = 'resourceGroup'

param aoaiName string
param modelName string
param deploymentName string
param thousandsOfTokensPerMinute int
param modelVersionName string
param isPTU bool
param enableDynamicQuota bool

resource aoai 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: aoaiName
}

//create a content filter policy 
module resposibleAiPolicy 'aoai-rai-policy.bicep' = {
  name: '${deployment().name}-rai-policy'
  params: {
    openAiServiceName: aoai.name
    policyName: '${deploymentName}-rai-policy'
  }
}

resource aoaiDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  name: deploymentName
  parent: aoai
  sku: {
    name: isPTU ? 'ProvisionedManaged' : 'Standard'
    capacity: thousandsOfTokensPerMinute
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersionName
    }
    versionUpgradeOption: 'OnceCurrentVersionExpired'
    dynamicThrottlingEnabled: enableDynamicQuota
    raiPolicyName: resposibleAiPolicy.outputs.responsibleAiPolicyName
  }
}
