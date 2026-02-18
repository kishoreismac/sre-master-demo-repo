targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention, the name of the resource group for your application will use this name, prefixed with rg-')
param environmentName string

@minLength(1)
@description('The location used for all deployed resources')
param location string

@description('Id of the user or app to assign application roles')
param principalId string = ''


var tags = {
  'azd-env-name': environmentName
}

// ⚠️ INTENTIONALLY MISSING TAGS on some resources
var tagsComplete = {
  'azd-env-name': environmentName
  purpose: 'sre-agent-cost-demo'
  'cost-center': 'engineering'
  owner: 'platform-team'
}

// ⚠️ Tags missing cost-center and owner
var tagsIncomplete = {
  'azd-env-name': environmentName
  purpose: 'sre-agent-cost-demo'
}

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}
module resources 'resources.bicep' = {
  scope: rg
  name: 'resources'
  params: {
    location: location
    tags: tags
    principalId: principalId
    tagsComplete: tagsComplete
    tagsIncomplete: tagsIncomplete
  }
}

module octopets_appinsights 'octopets-appinsights/octopets-appinsights.module.bicep' = {
  name: 'octopets-appinsights'
  scope: rg
  params: {
    location: location
    logAnalyticsWorkspaceId: resources.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
  }
}

output MANAGED_IDENTITY_CLIENT_ID string = resources.outputs.MANAGED_IDENTITY_CLIENT_ID
output MANAGED_IDENTITY_NAME string = resources.outputs.MANAGED_IDENTITY_NAME
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = resources.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_NAME
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID string = resources.outputs.AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID
output AZURE_CONTAINER_REGISTRY_NAME string = resources.outputs.AZURE_CONTAINER_REGISTRY_NAME
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = resources.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_NAME
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = resources.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_ID
output AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN string = resources.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN
output OCTOPETS_APPINSIGHTS_APPINSIGHTSCONNECTIONSTRING string = octopets_appinsights.outputs.appInsightsConnectionString
output VM1_NAME string = resources.outputs.vm1Name
output VM2_NAME string = resources.outputs.vm2Name
output ORPHANED_DISK_NAME string = resources.outputs.orphanedDiskName
output UNTAGGED_STORAGE_NAME string = resources.outputs.untaggedStorageName
output WEB_APP_URL string = resources.outputs.webAppUrl
output AZURE_LOCATION string = location
output SERVICE_API_NAME string = resources.outputs.webAppName
output SERVICE_API_RESOURCE_GROUP string = rg.name
