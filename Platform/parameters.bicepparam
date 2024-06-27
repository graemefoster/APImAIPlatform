using './main.bicep'

param location = 'australiaeast'
param platformResourceGroup = 'api-centre'
param apimName = 'grfapimaoai'

param existingAoaiResources = [
  {
    name: 'graemeopenai'
    resourceGroupName: 'graemeopenai'
  }
]

param aoaiPools = [
  {
    AzureOpenAIResourceNames: ['graemeopenai']
    PoolName: 'graemeopenai'
  }
]

//These are the consumer requests
//-------------------------------
param consumerDemands = [
  {
    name: 'graeme-demand'
    consumerName: 'graeme'
    requirements: [
      {
        modelName: 'text-embedding-ada-002'
        expectedThroughputThousandsOfTokensPerMinute: 1
        //contentSafetyFilter: {}

        platformTeamDeploymentMapping: 'embedding-model-2-test-2'
        platformTeamPoolMapping: 'graemeopenai'

        outsideDeploymentName: 'graeme-embedding-model-345'
      }
      {
        modelName: 'gpt-35-turbo'
        expectedThroughputThousandsOfTokensPerMinute: 1
        //contentSafetyFilter: {}

        platformTeamDeploymentMapping: 'gpt-35-turbo-test'
        platformTeamPoolMapping: 'graemeopenai'

        outsideDeploymentName: 'graeme-gpt-35-turbo-123'
      }
    ]
  }
]

//These are sizings based on consumer demand. This has to be done by the platform team
//-------------------------------
param deploymentRequirements = [
  {
    name: 'embedding-model-2-test'
    aoaiName: 'graemeopenai'
    aoaiResourceGroupName: 'graemeopenai'
    deploymentName: 'testdeploy'
    enableDynamicQuota: false
    isPTU: false
    model: 'text-embedding-ada-002'
    modelVersion: '2'
    thousandsOfTokensPerMinute: 2
  }
  {
    name: 'embedding-model-2-test-2'
    aoaiName: 'graemeopenai'
    aoaiResourceGroupName: 'graemeopenai'
    deploymentName: 'testdeploy'
    enableDynamicQuota: false
    isPTU: false
    model: 'text-embedding-ada-002'
    modelVersion: '2'
    thousandsOfTokensPerMinute: 2
  }
  {
    name: 'gpt-35-turbo-test'
    aoaiName: 'graemeopenai'
    aoaiResourceGroupName: 'graemeopenai'
    deploymentName: 'testdeploy2'
    enableDynamicQuota: false
    isPTU: false
    model: 'gpt-35-turbo'
    modelVersion: '0613'
    thousandsOfTokensPerMinute: 1
  }
]
