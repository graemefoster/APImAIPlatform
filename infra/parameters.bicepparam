using './main.bicep'

param location = 'australiaeast'
param platformResourceGroup = 'aiplat9'
param platformSlug = 'aiplat9'
param apimPublisherEmail = 'graemefoster@microsoft.com'
param apimPublisherName = 'Graeme Foster'
param environmentName = 'dev'
param ghRepo = 'aPImAIPlatform'
param ghUsername = 'graemefoster'
param tenantId = '16b3c013-d300-468d-ac64-7eda0820b6d3'
param azureAiStudioUsersGroupObjectId = '01a84fb4-5df7-4d37-ac5b-3ac350e21105'
param vectorizerEmbeddingsDeploymentName = 'embeddings'

