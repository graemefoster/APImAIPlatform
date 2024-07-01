using './main.bicep'

param location = 'australiaeast'
param platformResourceGroup = 'aiplatform'
param platformSlug = 'aiplat'
param apimPublisherEmail = 'graemefoster@microsoft.com'
param apimPublisherName = 'Graeme Foster'

param aoaiResources = [
  {
    name: 'graemeopenai'
  }
]

param aoaiPools = [
  {
    AzureOpenAIResourceNames: ['graemeopenai']
    PoolName: 'graemeopenai-pool'
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

        platformTeamDeploymentMapping: 'testdeploy'
        platformTeamPoolMapping: 'graemeopenai-pool'

        outsideDeploymentName: 'graeme-embedding-model-345'
      }
      {
        modelName: 'gpt-35-turbo'
        expectedThroughputThousandsOfTokensPerMinute: 2
        //contentSafetyFilter: {}

        platformTeamDeploymentMapping: 'testdeploy2'
        platformTeamPoolMapping: 'graemeopenai-pool'

        outsideDeploymentName: 'graeme-gpt-35-turbo-123'
      }
    ]
  }
]

//These are sizings based on consumer demand. This has to be done by the platform team
//-------------------------------
param deploymentRequirements = [
  {
    aoaiName: 'graemeopenai'
    deploymentName: 'testdeploy'
    enableDynamicQuota: false
    isPTU: false
    model: 'text-embedding-ada-002'
    modelVersion: '2'
    thousandsOfTokensPerMinute: 2
  }
  {
    aoaiName: 'graemeopenai'
    deploymentName: 'testdeploy2'
    enableDynamicQuota: false
    isPTU: false
    model: 'gpt-35-turbo'
    modelVersion: '0613'
    thousandsOfTokensPerMinute: 5
  }
]
