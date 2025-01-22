using './main.bicep'

param location = 'australiaeast'
param platformResourceGroup = 'aiplat20'
param platformSlug = 'aiplat20'
param apimPublisherEmail = 'graemefoster@microsoft.com'
param apimPublisherName = 'Graeme Foster'
param environmentName = 'dev'
param ghRepo = 'aPImAIPlatform'
param ghUsername = 'graemefoster'
param tenantId = 'a77c67fe-34bf-43d1-9652-7150e6c155c3'
param azureAiStudioUsersGroupObjectId = '22a4264a-6a35-4560-8961-770d189c65e3'
param vectorizerEmbeddingsDeploymentName = 'embeddings'

param azureMachineLearningServicePrincipalId = '02bef2cc-1387-4918-b91d-bbfc606fb7ed'

param deployDeveloperVm = false
param developerUsername = 'developer'
param developerPassword = ''

//sample features
param deploySubscriptionKeyAugmentingApi = true

param deployAIStudio = true

