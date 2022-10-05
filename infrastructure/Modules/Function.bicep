@description('Instrumentation key for the ap insigts resource to send app logs to')
param appInsightInstrumantionKey string
@description('Name of the functions resource to deploy')
param functionAppName string
@description('Name of the app service plan for the function resource')
param hostingPlanName string
@description('Name of the storage account for the function resource')
param storageAccountName string
@description('Endpoint to the app config resource')
param appConfigStoreEndpoint string
@description('Origin URL that should be allowed to access this API')
param allowedOrigins array = []
@description('Location to use for the resources')
param location string
@description('Tags to tag the resources with')
param tags object

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: tags
}

resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: hostingPlanName
  location: location
  kind: 'functionapp'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
  }
  properties: {
    reserved: false
  }
  tags: tags
}

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    siteConfig: {
      functionAppScaleLimit: 10
      cors: {
        allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
      }
    }
  }
  tags: tags
}

resource functionConfig 'Microsoft.Web/sites/config@2022-03-01' = {
  name: 'appsettings'
  kind: 'string'
  parent: functionApp
  properties: {
    AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccount.listKeys().keys[0].value}'
    FUNCTIONS_EXTENSION_VERSION: '~4'
    FUNCTIONS_WORKER_RUNTIME: 'dotnet-isolated'
    APPINSIGHTS_INSTRUMENTATIONKEY: appInsightInstrumantionKey
    APPCONFIG_ENDPOINT: appConfigStoreEndpoint
  }
}

output procipleId string = functionApp.identity.principalId
output endpoint string = functionApp.properties.defaultHostName
