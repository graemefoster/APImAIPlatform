import { DeploymentRequirement, AzureOpenAIResourceOutput } from '../types.bicep'

param deploymentRequirements DeploymentRequirement[]
param aoaiOutputs AzureOpenAIResourceOutput[]

module aoaiDeployment './aoaideployment.bicep' = [
  for deployment in deploymentRequirements: {
    name: '${az.deployment().name}-${deployment.deploymentName}'
    params: {
      aoaiName: filter(
        aoaiOutputs, 
        aoai => aoai.inputName == deployment.aoaiName)[0].resourceName
      deploymentName: deployment.deploymentName
      enableDynamicQuota: deployment.enableDynamicQuota
      isPTU: deployment.isPTU
      modelName: deployment.model
      modelVersionName: deployment.modelVersion
      thousandsOfTokensPerMinute: deployment.thousandsOfTokensPerMinute
    }
  }
]
