targetScope = 'resourceGroup'

param deploymentIdentityName string
param acrName string
param ghRepo string
param ghUsername string
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
    name: 'federatedIdentityCredentials'
    properties: {
      audiences: [
        'api://AzureADTokenExchange'
      ]
      issuer: 'https://token.actions.githubusercontent.com'
      subject: 'repo:${ghUsername}/${ghRepo}' //:environment:${ghEnvName}'
    }
  }
}

var acrPush = '8311e382-0749-4cb8-b61a-304f252e45ec'

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


output acrHostName string = acr.properties.loginServer
output ghActionsClientId string = githubIdentity.properties.clientId

