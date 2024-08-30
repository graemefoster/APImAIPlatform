using './main.bicep'

param location = 'australiaeast'
param platformResourceGroup = 'aiplat11'
param platformSlug = 'aiplat11'
param apimPublisherEmail = 'graemefoster@microsoft.com'
param apimPublisherName = 'Graeme Foster'
param environmentName = 'dev'
param ghRepo = 'aPImAIPlatform'
param ghUsername = 'graemefoster'
param tenantId = 'a77c67fe-34bf-43d1-9652-7150e6c155c3'
param azureAiStudioUsersGroupObjectId = '1381b12e-7398-41ea-9faa-fce77bff0ec9'
param vectorizerEmbeddingsDeploymentName = 'embeddings'

param deployDeveloperVm = false
param developerUsername = 'developer'
param developerPassword = ''

//sample features
param deploySubscriptionKeyAugmentingApi = true
