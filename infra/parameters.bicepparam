using './main.bicep'

param location = 'australiaeast'
param platformResourceGroup = 'aiplat24'
param platformSlug = 'aiplat24'
param apimPublisherEmail = 'graemefoster@microsoft.com'
param apimPublisherName = 'Graeme Foster'
param environmentName = 'dev'
param ghRepo = 'aPImAIPlatform'
param ghUsername = 'graemefoster'
param tenantId = 'a77c67fe-34bf-43d1-9652-7150e6c155c3'
param vectorizerEmbeddingsDeploymentName = 'embeddings'

//Deploy an API that can augment a subscription key to a JWT protected request. Useful if your tooling (PromptFlow)
//doesn't support adding JWT and API-Key auth.
param deploySubscriptionKeyAugmentingApi = true


//To keep this fully private we can deploy a jumpbox that you can either RDP to or hook up to a bastion host
param deployJumpBox = false
param developerUsername = 'developer'
param developerPassword = ''

//AI Foundry triggers
param deployAIFoundry = true
param azureaiFoundryUsersGroupObjectId = '22a4264a-6a35-4560-8961-770d189c65e3'

//deploy a sample Prompt Flow app that uses AI Central -> APIm -> AOAI
param deployPromptFlowSampleApp = true

