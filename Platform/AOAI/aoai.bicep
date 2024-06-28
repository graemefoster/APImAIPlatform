targetScope = 'resourceGroup'

param aoaiName string

resource aoai 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: aoaiName
}

output aoaiHostName string = aoai.properties.endpoint
