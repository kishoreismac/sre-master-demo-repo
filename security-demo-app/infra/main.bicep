targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Secret expiration in days from now (set low to trigger SRE Agent detection)')
param secretExpirationDays int = 14

@description('Current time for secret expiration calculation')
param currentTime string = utcNow()

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = {
  'azd-env-name': environmentName
  purpose: 'sre-agent-security-demo'
}

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

// Deploy security demo resources
module securityDemo 'resources.bicep' = {
  name: 'security-demo-resources'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
    secretExpirationDays: secretExpirationDays
    currentTime: currentTime
  }
}

output RESOURCE_GROUP_NAME string = rg.name
output VNET_NAME string = securityDemo.outputs.vnetName
output NSG_NAME string = securityDemo.outputs.nsgName
output STORAGE_ACCOUNT_NAME string = securityDemo.outputs.storageAccountName
output KEY_VAULT_NAME string = securityDemo.outputs.keyVaultName
output PRIVATE_DNS_ZONE_NAME string = securityDemo.outputs.privateDnsZoneName
output WEB_APP_URL string = securityDemo.outputs.webAppUrl

// Outputs for azd deployment
output AZURE_LOCATION string = location
output SERVICE_API_NAME string = securityDemo.outputs.webAppName
output SERVICE_API_RESOURCE_GROUP string = rg.name
