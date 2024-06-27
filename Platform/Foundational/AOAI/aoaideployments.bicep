targetScope = 'subscription'

type DeploymentRequirement = {
  aoaiResourceGroupName: string
  aoaiName: string
  name: string
  deploymentName: string
  model: string
  modelVersion: string
  thousandsOfTokensPerMinute: int
  isPTU: bool
  enableDynamicQuota: bool
}

param deploymentRequirements DeploymentRequirement[]

module aoaiDeployment './aoaideployment.bicep' = [
  for deployment in deploymentRequirements: {
    name: '${az.deployment().name}-deployment-${deployment.name}'
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
