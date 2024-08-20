targetScope = 'resourceGroup'

import { DeploymentRequirement } from '../types.bicep'

param aoaiName string
param aoaiDeployment DeploymentRequirement

resource aoai 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: aoaiName
}

//create a content filter policy 
module resposibleAiPolicy 'aoai-rai-policy.bicep' = {
  name: '${deployment().name}-rai-policy'
  params: {
    openAiServiceName: aoai.name
    policyName: '${aoaiDeployment.deploymentName}-rai-policy'
  }
}

resource aoaiDeploymentResource 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  name: aoaiDeployment.deploymentName
  parent: aoai
  sku: {
    name: aoaiDeployment.deploymentType == 'PTU' 
      ? 'ProvisionedManaged' 
      : aoaiDeployment.deploymentType == 'PAYG' 
        ? 'Standard'
        : aoaiDeployment.deploymentType == 'GlobalBatch'
          ? 'GlobalBatch'
          : 'GlobalStandard'
    capacity: aoaiDeployment.thousandsOfTokensPerMinute
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: aoaiDeployment.model
      version: aoaiDeployment.modelVersion
    }
    versionUpgradeOption: 'OnceCurrentVersionExpired'
    dynamicThrottlingEnabled: aoaiDeployment.enableDynamicQuota
    raiPolicyName: resposibleAiPolicy.outputs.responsibleAiPolicyName
  }
}
