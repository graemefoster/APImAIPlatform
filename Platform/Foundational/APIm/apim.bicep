targetScope = 'resourceGroup'

param apimName string

resource apim 'Microsoft.ApiManagement/service@2019-12-01' existing = {
  name: apimName
}

output apimId string = apim.id
output apimName string = apim.name
