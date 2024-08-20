targetScope = 'resourceGroup'

import {
  AzureOpenAIResource
  AzureOpenAIResourceOutput
} from '../types.bicep'

param aoaiNames AzureOpenAIResource[]
param privateDnsZoneId string
param privateEndpointSubnetId string
param resourcePrefix string
param location string = resourceGroup().location
param logAnalyticsId string

module aoai './aoai.bicep' = [
  for aoaiName in aoaiNames: {
    name: '${deployment().name}-aoai-${aoaiName.name}'
    scope: resourceGroup()
    params: {
      aoaiName: aoaiName.name
      privateDnsZoneId: privateDnsZoneId
      privateEndpointSubnetId: privateEndpointSubnetId
      location: aoaiName.location
      resourcePrefix: resourcePrefix
      logAnalyticsId: logAnalyticsId
    }
  }
]

output aoaiResources AzureOpenAIResourceOutput[] = [for idx in range(0, length(aoaiNames)): aoai[idx].outputs.aoaiInformation]
