import { DeploymentRequirement, AzureOpenAIResourceOutput } from '../types.bicep'

param deploymentRequirements DeploymentRequirement[]
param aoaiOutputs AzureOpenAIResourceOutput[]

@batchSize(1)
module aoaiDeployment './aoaideployment.bicep' = [
  for idx in range(0, length(deploymentRequirements)): {
    name: '${az.deployment().name}-${idx}'
    params: {
      aoaiName: filter(aoaiOutputs, aoai => aoai.inputName == deploymentRequirements[idx].aoaiName)[0].resourceName
      aoaiDeployment: deploymentRequirements[idx]
    }
  }
]
