using './main.bicep'

param location = 'australiaeast'
param platformResourceGroup = 'aiplatform'
param platformSlug = 'aiplat'
param apimPublisherEmail = 'graemefoster@microsoft.com'
param apimPublisherName = 'Graeme Foster'
param environmentName = 'dev'
param ghRepo = 'aPImAIPlatform'
param ghUsername = 'graemefoster'

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
param mappedDemands = [
  {
    consumerName: 'consumer-1'
    requirements: [
      {
        id: 'embeddings-for-my-purpose'
        platformTeamDeploymentMapping: 'testdeploy'
        platformTeamPoolMapping: 'graemeopenai-pool'
        outsideDeploymentName: 'graeme-embedding-model-345' //This stays static meaning the Consumer never worries about deployment names changing
      }
      {
        id: 'gpt35-for-my-purpose'
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

param consumerDemands = [
  {
    consumerName: 'consumer-1'
    requestName: 'my-amazing-service'
    contactEmail: 'engineer.name@myorg.com'
    costCentre: '92304'
    models: [
      {
        id: 'embeddings-for-my-purpose'
        modelName: 'gpt4o'
        environments: {
          dev: { thousandsOfTokens: 1, deployAt: '02/jul/2024' }
          test: { thousandsOfTokens: 1, deployAt: '02/jul/2024' }
          prod: { thousandsOfTokens: 15, deployAt: '02/jul/2024' }
        }
        contentSafety: {
          prompt: {
            abuse: 'high'
          }
          response: {
            abuse: 'High'
          }
        }
      }
      {
        id: 'gpt35-for-my-purpose'
        modelName: 'gpt-35-turbo'
        environments: {
          dev: { thousandsOfTokens: 1, deployAt: '02/jul/2024' }
          test: { thousandsOfTokens: 1, deployAt: '02/jul/2024' }
          prod: { thousandsOfTokens: 15, deployAt: '02/jul/2024' }
        }
        contentSafety: {
          prompt: {
            abuse: 'high'
          }
          response: {
            abuse: 'High'
          }
        }
      }
    ]
  }
]
