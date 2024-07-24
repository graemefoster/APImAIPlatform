using './main.bicep'

param location = 'eastus2'
param platformResourceGroup = 'aiplat2'
param platformSlug = 'aiplat2'
param apimPublisherEmail = 'graemefoster@microsoft.com'
param apimPublisherName = 'Graeme Foster'
param environmentName = 'dev'
param ghRepo = 'aPImAIPlatform'
param ghUsername = 'graemefoster'
param tenantId = '16b3c013-d300-468d-ac64-7eda0820b6d3'

param aoaiResources = [
  {
    name: 'graemeopenai'
  }
  {
    name: 'graemeopenai2'
  }
]

param aoaiPools = [
  {
    PoolName: 'graemeopenai-pool'
    AzureOpenAIResources: [
      {
        name: 'graemeopenai'
        priority: 1 //low is higher priority
      }
      {
        name: 'graemeopenai2'
        priority: 2
      }
    ]
  }
  {
    PoolName: 'graemeopenai-embedding-pool'
    AzureOpenAIResources: [
      {
        name: 'graemeopenai'
        priority: 1
      }
      {
        name: 'graemeopenai2'
        priority: 1
      }
    ]
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
        platformTeamPoolMapping: 'graemeopenai-embedding-pool'
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
    thousandsOfTokensPerMinute: 5
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
  {
    aoaiName: 'graemeopenai2'
    deploymentName: 'testdeploy'
    enableDynamicQuota: false
    isPTU: false
    model: 'text-embedding-ada-002'
    modelVersion: '2'
    thousandsOfTokensPerMinute: 5
  }
  {
    aoaiName: 'graemeopenai2'
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
          dev: { thousandsOfTokens: 1, deployAt: '2024-07-02T00:00:0000' }
          test: { thousandsOfTokens: 1, deployAt: '2024-07-02T00:00:0000' }
          prod: { thousandsOfTokens: 15, deployAt: '2024-07-02T00:00:0000' }
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
          dev: { thousandsOfTokens: 1, deployAt: '2024-07-02T00:00:0000' }
          test: { thousandsOfTokens: 1, deployAt: '2024-07-02T00:00:0000' }
          prod: { thousandsOfTokens: 15, deployAt: '2024-07-02T00:00:0000' }
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
