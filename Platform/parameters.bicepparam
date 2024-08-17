using './main.bicep'

param location = 'australiaeast'
param platformResourceGroup = 'aiplat7'
param platformSlug = 'aiplat7'
param apimPublisherEmail = 'graemefoster@microsoft.com'
param apimPublisherName = 'Graeme Foster'
param environmentName = 'dev'
param ghRepo = 'aPImAIPlatform'
param ghUsername = 'graemefoster'
param tenantId = '16b3c013-d300-468d-ac64-7eda0820b6d3'
param azureAiStudioUsersGroupObjectId = '01a84fb4-5df7-4d37-ac5b-3ac350e21105'
param vectorizerEmbeddingsDeploymentName = 'embeddings'

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
// I've used the same inside / outside names for now to support my AI Studio test work
param mappedDemands = [
  {
    consumerName: 'consumer-1'
    requirements: [
      {
        id: 'embeddings-for-my-purpose'
        platformTeamDeploymentMapping: 'text-embedding-ada-002'
        platformTeamPoolMapping: 'graemeopenai-embedding-pool'
        outsideDeploymentName: 'embeddings' //This stays static meaning the Consumer never worries about deployment names changing
      }
      {
        id: 'gpt35-for-my-purpose'
        platformTeamDeploymentMapping: 'testdeploy2'
        platformTeamPoolMapping: 'graemeopenai-pool'
        outsideDeploymentName: 'gpt35'
      }
    ]
  }
  {
    consumerName: 'aistudio'
    requirements: [
      {
        id: 'aistudioembeddings'
        platformTeamDeploymentMapping: 'text-embedding-ada-002'
        platformTeamPoolMapping: 'graemeopenai-embedding-pool'
        outsideDeploymentName: 'text-embedding-ada-002' //This stays static meaning the Consumer never worries about deployment names changing
      }
      {
        id: 'aistudiogpt35'
        platformTeamDeploymentMapping: 'testdeploy2'
        platformTeamPoolMapping: 'graemeopenai-pool'
        outsideDeploymentName: 'testdeploy2'
      }
    ]
  }
]

//These are sizings based on consumer demand. This has to be done by the platform team
//-------------------------------
param deploymentRequirements = [
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
    deploymentName: 'testdeploy2'
    enableDynamicQuota: false
    isPTU: false
    model: 'gpt-35-turbo'
    modelVersion: '0613'
    thousandsOfTokensPerMinute: 5
  }
  {
    aoaiName: 'graemeopenai'
    deploymentName: 'text-embedding-ada-002'
    enableDynamicQuota: false
    isPTU: false
    model: 'text-embedding-ada-002'
    modelVersion: '2'
    thousandsOfTokensPerMinute: 2
  }
  {
    aoaiName: 'graemeopenai2'
    deploymentName: 'text-embedding-ada-002'
    enableDynamicQuota: false
    isPTU: false
    model: 'text-embedding-ada-002'
    modelVersion: '2'
    thousandsOfTokensPerMinute: 2
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
        modelName: 'text-embedding-ada-002'
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
  {
    consumerName: 'aistudio'
    requestName: 'aistudio-requirements'
    contactEmail: 'engineer.name@myorg.com'
    costCentre: '123433'
    models: [
      {
        id: 'aistudioembeddings'
        modelName: 'text-embedding-ada-002'
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
        id: 'aistudiogpt35'
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
