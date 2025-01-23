targetScope = 'resourceGroup'

param acrPullIdentityName string
param deploymentIdentityName string
param acrName string
param ghRepo string
param ghUsername string
param appServicePlanName string
param environmentName string
param location string = resourceGroup().location

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: acrName
  location: location
  sku: { name: 'Standard' }
  properties: {
    adminUserEnabled: false
    anonymousPullEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

resource githubIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: deploymentIdentityName
  location: location

  resource githubFederation 'federatedIdentityCredentials' = {
    name: 'federatedIdentityCredentials-${environmentName}'
    properties: {
      audiences: [
        'api://AzureADTokenExchange'
      ]
      issuer: 'https://token.actions.githubusercontent.com'
      subject: 'repo:${ghUsername}/${ghRepo}:environment:${environmentName}'
    }
  }
}

resource acrPuller 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: acrPullIdentityName
  location: location
}

var acrPush = '8311e382-0749-4cb8-b61a-304f252e45ec'
var acrPull = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource acrPushRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    githubIdentity.name,
    acrPush,
    acr.id,
    resourceGroup().id
  )
  scope: acr
  properties: {
    principalId: githubIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', acrPush)
  }
}

resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    acrPuller.name,
    acrPull,
    acr.id,
    resourceGroup().id
  )
  scope: acr
  properties: {
    principalId: acrPuller.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', acrPull)
  }
}

//app service to host the PromptFlows
resource appservice 'Microsoft.Web/serverfarms@2023-12-01' = {
  location: location
  name: appServicePlanName
  sku: {
    name: 'P0v3'
    capacity: 1
  }
  properties: {
    zoneRedundant: false
    reserved: true
  }
}


output acrHostName string = acr.properties.loginServer
output ghActionsClientId string = githubIdentity.properties.clientId
output acrName string = acr.name
output aspId string = appservice.id
output acrPullerManagedIdentityName string = acrPuller.name
