@description('Location for all resources')
param location string

@description('Resource token for unique naming')
param resourceToken string

@description('Tags for all resources')
param tags object

@description('Secret expiration in days from now')
param secretExpirationDays int

@description('Current time passed from main.bicep')
param currentTime string

// ============================================================================
// VIRTUAL NETWORK + SUBNET
// ============================================================================
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-${resourceToken}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-app'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: 'snet-data'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

// ============================================================================
// NSG WITH INTENTIONALLY OPEN RULES (SRE Agent should detect these)
// ============================================================================
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'nsg-${resourceToken}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      // ⚠️ INTENTIONALLY INSECURE: SSH open to internet
      {
        name: 'AllowSSH-FromAnywhere'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'  // 0.0.0.0/0 equivalent
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          description: 'INSECURE: SSH open to internet - SRE Agent should flag this'
        }
      }
      // ⚠️ INTENTIONALLY INSECURE: RDP open to internet
      {
        name: 'AllowRDP-FromAnywhere'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
          description: 'INSECURE: RDP open to internet - SRE Agent should flag this'
        }
      }
    ]
  }
}

// ============================================================================
// STORAGE ACCOUNT (Policy-compliant but we'll check other issues)
// ============================================================================
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'st${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    // Policy requires these to be disabled
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'data'
  properties: {
    publicAccess: 'None'
  }
}

// ============================================================================
// KEY VAULT WITH EXPIRING SECRETS (SRE Agent should detect these)
// ============================================================================
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

// ⚠️ INTENTIONALLY EXPIRING SOON: Secrets with near expiration
resource expiringSecret1 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'sql-connection-string'
  properties: {
    value: 'Server=tcp:demo.database.windows.net;Database=mydb;'
    attributes: {
      enabled: true
      // Expires in X days from deployment
      exp: dateTimeToEpoch(dateTimeAdd(currentTime, 'P${secretExpirationDays}D'))
    }
  }
}

resource expiringSecret2 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'api-key-external'
  properties: {
    value: 'demo-api-key-12345'
    attributes: {
      enabled: true
      exp: dateTimeToEpoch(dateTimeAdd(currentTime, 'P${secretExpirationDays + 5}D'))
    }
  }
}

resource expiringSecret3 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'storage-key-backup'
  properties: {
    value: 'demo-storage-key'
    attributes: {
      enabled: true
      exp: dateTimeToEpoch(dateTimeAdd(currentTime, 'P${secretExpirationDays + 10}D'))
    }
  }
}

// ============================================================================
// PRIVATE DNS ZONE WITHOUT VNET LINK (SRE Agent should detect this)
// ============================================================================
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.database.windows.net'
  location: 'global'
  tags: tags
}

// ⚠️ INTENTIONALLY MISSING: No VNet link created
// This is the issue - the DNS zone exists but isn't linked to the VNet
// SRE Agent should detect this misconfiguration

// ============================================================================
// APP SERVICE: Working web app connected to VNet, Key Vault, and Storage
// The app works fine, but the infrastructure has security issues
// ============================================================================
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'plan-${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'S1'  // S1 required for VNet integration
    tier: 'Standard'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// ✅ WORKING APP: Todo app connected to all infrastructure resources
// - VNet integration: Traffic goes through subnet protected by the insecure NSG
// - Key Vault: Reads secrets (which are expiring soon)
// - Storage: Stores todo item attachments
resource webApp 'Microsoft.Web/sites@2022-09-01' = {
  name: 'app-${resourceToken}'
  location: location
  tags: union(tags, {
    'azd-service-name': 'api'
  })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: vnet.properties.subnets[0].id  // snet-app with the insecure NSG
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      appSettings: [
        {
          // Key Vault name for the app to connect
          name: 'KEY_VAULT_NAME'
          value: keyVault.name
        }
        {
          // Reference secret from Key Vault (which is expiring soon!)
          name: 'SQL_CONNECTION_STRING'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=sql-connection-string)'
        }
        {
          // Reference secret from Key Vault (expiring soon!)
          name: 'API_KEY'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=api-key-external)'
        }
        {
          name: 'AZURE_STORAGE_ACCOUNT_NAME'
          value: storageAccount.name
        }
        {
          name: 'AZURE_STORAGE_CONTAINER_NAME'
          value: 'data'
        }
        {
          // Enable Oryx build during deployment (runs npm install)
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
      ]
      vnetRouteAllEnabled: true  // Route all traffic through VNet
    }
    httpsOnly: true
  }
}

// VNet integration configuration
resource webAppVnetConnection 'Microsoft.Web/sites/virtualNetworkConnections@2022-09-01' = {
  parent: webApp
  name: 'vnet-connection'
  properties: {
    vnetResourceId: vnet.properties.subnets[0].id
    isSwift: true
  }
}

// ============================================================================
// RBAC: Grant App Service access to Key Vault secrets
// ============================================================================
// Key Vault Secrets User role
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, webApp.id, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    principalId: webApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// RBAC: Grant App Service access to Storage Account
// ============================================================================
// Storage Blob Data Contributor role
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, webApp.id, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    principalId: webApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================
output vnetName string = vnet.name
output nsgName string = nsg.name
output storageAccountName string = storageAccount.name
output keyVaultName string = keyVault.name
output privateDnsZoneName string = privateDnsZone.name
output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output webAppPrincipalId string = webApp.identity.principalId
