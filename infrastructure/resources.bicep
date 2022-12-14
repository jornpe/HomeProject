param repositoryUrl string
@description('Name of the application to be deployed')
param application string
@description('Tags to add the all resources that is being deployed')
param tags object
@description('Location to use for the resources')
param location string

var appInsightName = 'appi-${application}'
var websiteName = 'site-${application}'
var appServicePlanName = 'plan-${application}'
var functionAppName = 'fnapp-${application}'
var iotHubName = 'iot-${application}'
var appConfigName = 'appc-${application}'
var functionStorageAccountName = 'function${uniqueString(resourceGroup().id)}'
var storageAccountName = '${toLower(application)}${uniqueString(resourceGroup().id)}'
var domain = 'jornp.no'
var customDomainNames = [
  { 
    domain: domain
    validationMethod: 'dns-txt-token'
   }
   {
    domain: 'www.${domain}'
    validationMethod: 'cname-delegation'
   }
  ]
    

module appInsight 'Modules/appInsight.bicep' = {
  name: 'AppInsight'
  params: {
    appInsightName: appInsightName 
    location: location
    tags: tags
  }
}

module appConfig 'Modules/appConfig.bicep' = {
  name: 'AppConfigStore'
  params: {
    configStoreName: appConfigName
    location: location
    tags: tags
  }
}

module iotHub 'Modules/IotHub.bicep' = {
  name: 'IotHub'
  params: {
    configStoreName: appConfigName
    iotHubName: iotHubName
    location: location
    tags: tags
  }
  dependsOn:[
    appConfig
  ]
}

module website 'Modules/StaticWebApp.bicep' = {
  name: 'webSite'
  params: {
    tags: tags
    repositoryUrl: repositoryUrl
    location: location
    appInsightInstrumantionKey: appInsight.outputs.InstrumentationKey
    websiteName: websiteName
  }
}

module dnsZone 'Modules/dns.bicep' = {
  name: 'dns'
  params: {
    zoneName: domain
    defaultHostname: website.outputs.defaultHostname
    staticSiteName: website.outputs.staticSiteName
  }
}

module customDomainName 'Modules/customDomain.bicep' = {
  name: 'customDomainNames'
  params: {
    domainNames: customDomainNames
    staticSiteName: website.outputs.staticSiteName
  }
}

var allowedOrigins = [for domainName in customDomainNames: 'https://${domainName.domain}']
module functionApp 'Modules/Function.bicep' = {
  name: functionAppName
  params: {
    appInsightInstrumantionKey: appInsight.outputs.InstrumentationKey
    functionAppName: functionAppName
    hostingPlanName: appServicePlanName
    storageAccountName: functionStorageAccountName
    appConfigStoreEndpoint: appConfig.outputs.appConfigEndpoint
    allowedOrigins: concat([ 'https://${website.outputs.defaultHostname}' ], allowedOrigins) 
    location: location
    iotHubName: iotHubName
    tags: tags
  }
  dependsOn:[
    iotHub
  ]
}

module storageAccount 'Modules/storage.bicep' = {
  name: 'StorageAccount'
  params: {
    configStoreName: appConfigName
    location: location
    storageAccountName: storageAccountName
  }
}

module iotHubRoleAssignment 'RoleAssignments/iotHubRoleAssignments.bicep' = {
  name: 'IotHubRoleAssignment'
  params: {
    iotHubName: iotHubName
    principalId: functionApp.outputs.procipleId
  }
  dependsOn: [
    iotHub
    functionApp
  ]
}

module appConfigRoleAssignment 'RoleAssignments/appConfigRoleAssignment.bicep' = {
  name: 'AppConfigRoleAssignment'
  params: {
    principalId: functionApp.outputs.procipleId
    appConfigStoreName: appConfigName
  }
  dependsOn: [
    appConfig
    functionApp
  ]
}

module storageAccountRoleAssignment 'RoleAssignments/storageRoleAssignment.bicep' = {
  name: 'StorageAccountRoleAssignment'
  params: {
    principalId: functionApp.outputs.procipleId
    storageAccountName: storageAccountName
  }
}
