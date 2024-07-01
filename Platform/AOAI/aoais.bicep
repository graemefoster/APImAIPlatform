targetScope = 'resourceGroup'

import {
  AzureOpenAIResource
} from '../types.bicep'

param aoaiNames AzureOpenAIResource[]
param privateDnsZoneId string
param privateEndpointSubnetId string
param resourcePrefix string
param location string = resourceGroup().location

module aoai './aoai.bicep' = [
  for aoaiName in aoaiNames: {
    name: '${deployment().name}-aoai-${aoaiName.name}'
    scope: resourceGroup()
    params: {
      aoaiName: aoaiName.name
      privateDnsZoneId: privateDnsZoneId
      privateEndpointSubnetId: privateEndpointSubnetId
      location: location
      resourcePrefix: resourcePrefix
    }
  }
]

