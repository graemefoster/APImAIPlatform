targetScope = 'subscription'

import { DeploymentRequirement } from '../types.bicep'

param deploymentRequirements DeploymentRequirement[]

module aoaiDeployment './aoaideployment.bicep' = [
  for deployment in deploymentRequirements: {
    name: '${az.deployment().name}-deployment-${deployment.deploymentName}'
    scope: resourceGroup(deployment.aoaiResourceGroupName)
    params: {
      aoaiName: deployment.aoaiName
      deploymentName: deployment.deploymentName
      enableDynamicQuota: deployment.enableDynamicQuota
      isPTU: deployment.isPTU
      modelName: deployment.model
      modelVersionName: deployment.modelVersion
      thousandsOfTokensPerMinute: deployment.thousandsOfTokensPerMinute
    }
  }
]
