targetScope = 'resourceGroup'

param location string
param environmentName string

var resourceToken = toLower(uniqueString(resourceGroup().id, environmentName))

resource search 'Microsoft.Search/searchServices@2024-03-01-preview' = {
  name: 'search-${resourceToken}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'basic'
  }
  properties: {
    hostingMode: 'default'
    partitionCount: 1
    publicNetworkAccess: 'Enabled'
    replicaCount: 1
  }
}

output AZURE_SEARCH_ENDPOINT string = 'https://${search.name}.search.windows.net'
output AZURE_SEARCH_RESOURCE_ID string = search.id
