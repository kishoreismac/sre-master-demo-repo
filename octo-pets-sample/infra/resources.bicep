@description('The location used for all deployed resources')
param location string = resourceGroup().location
@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Tags that will be applied to all resources')
param securedemoinfratags object = {}

var resourceToken = uniqueString(resourceGroup().id)

// ============================================================================
// cost optimization params
// ============================================================================

@description('Complete tags with cost-center and owner')
param tagsComplete object

@description('Incomplete tags missing cost-center and owner')
param tagsIncomplete object


// ============================================================================
// secure demo params
// ============================================================================

@description('Secret expiration in days from now')
param secretExpirationDays int

@description('Current time passed from main.bicep')
param currentTime string


resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-${resourceToken}'
  location: location
  tags: tags
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: replace('acr-${resourceToken}', '-', '')
  location: location
  sku: {
    name: 'Basic'
  }
  tags: tags
}

resource caeMiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, managedIdentity.id, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d'))
  scope: containerRegistry
  properties: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId:  subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'law-${resourceToken}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
  tags: tags
}

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2024-02-02-preview' = {
  name: 'cae-${resourceToken}'
  location: location
  properties: {
    workloadProfiles: [{
      workloadProfileType: 'Consumption'
      name: 'consumption'
    }]
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
  tags: tags

  resource aspireDashboard 'dotNetComponents' = {
    name: 'aspire-dashboard'
    properties: {
      componentType: 'AspireDashboard'
    }
  }

}


// ============================================================================
// COST-OPTIMIZATION-DEMO
// ============================================================================


// ============================================================================
// VIRTUAL NETWORK (shared)
// ============================================================================
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-${resourceToken}'
  location: location
  tags: tagsComplete
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-vms'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

// ============================================================================
// VM 1: Idle/Underutilized VM (SRE Agent should detect low CPU)
// ============================================================================
resource nic1 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nic-idle-vm-${resourceToken}'
  location: location
  tags: tagsComplete
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm1 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'vm-idle-${resourceToken}'
  location: location
  tags: tagsComplete
  properties: {
    // ⚠️ OVERSIZED: D2s_v3 for an idle workload
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic1.id
        }
      ]
    }
    osProfile: {
      computerName: 'vm-idle'
      adminUsername: 'azureuser'
      adminPassword: 'P@ssw0rd1234!'  // Demo only - use Key Vault in production
    }
  }
}

// ============================================================================
// VM 2: Another idle VM (demonstrates pattern of waste)
// ============================================================================
resource nic2 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nic-batch-vm-${resourceToken}'
  location: location
  tags: tagsComplete
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm2 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'vm-batch-${resourceToken}'
  location: location
  tags: tagsComplete
  properties: {
    // ⚠️ OVERSIZED: D4s_v3 sitting idle
    hardwareProfile: {
      vmSize: 'Standard_D4s_v3'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic2.id
        }
      ]
    }
    osProfile: {
      computerName: 'vm-batch'
      adminUsername: 'azureuser'
      adminPassword: 'P@ssw0rd1234!'
    }
  }
}

// ============================================================================
// ORPHANED DISK (not attached to any VM - SRE Agent should detect)
// ============================================================================
resource orphanedDisk 'Microsoft.Compute/disks@2023-04-02' = {
  name: 'disk-orphaned-${resourceToken}'
  location: location
  // ⚠️ INTENTIONALLY MISSING TAGS
  tags: tagsIncomplete
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: 128
  }
}

// Another orphaned disk
resource orphanedDisk2 'Microsoft.Compute/disks@2023-04-02' = {
  name: 'disk-backup-old-${resourceToken}'
  location: location
  tags: tagsIncomplete
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: 256
  }
}

// ============================================================================
// STORAGE ACCOUNTS - Some with missing tags
// ============================================================================

// Properly tagged storage
resource storageTagged 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'sttagged${resourceToken}'
  location: location
  tags: tagsComplete
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// ⚠️ MISSING TAGS: cost-center and owner
resource storageUntagged1 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'stuntagged1${resourceToken}'
  location: location
  tags: tagsIncomplete
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource storageUntagged2 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'stuntagged2${resourceToken}'
  location: location
  // ⚠️ NO TAGS AT ALL
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// ============================================================================
// APP SERVICE: Working web app connected to resources
// ============================================================================
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'plan-${resourceToken}'
  location: location
  tags: tagsComplete
  sku: {
    name: 'S1'
    tier: 'Standard'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2022-09-01' = {
  name: 'app-${resourceToken}'
  location: location
  tags: union(tagsComplete, {
    'azd-service-name': 'api'
  })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      appSettings: [
        {
          name: 'AZURE_STORAGE_ACCOUNT_NAME'
          value: storageTagged.name
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
      ]
    }
    httpsOnly: true
  }
}

// Grant App Service access to Storage
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageTagged.id, webApp.id, storageBlobDataContributorRoleId)
  scope: storageTagged
  properties: {
    principalId: webApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalType: 'ServicePrincipal'
  }
}


// ============================================================================
// SECURE-DEMO
// ============================================================================

// ============================================================================
// VIRTUAL NETWORK + SUBNET
// ============================================================================
resource secure_vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-secure-${resourceToken}'
  location: location
  tags: securedemoinfratags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-app'
        properties: {
          addressPrefix: '10.1.1.0/24'
          networkSecurityGroup: {
            id: secure_nsg.id
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
          addressPrefix: '10.1.2.0/24'
        }
      }
    ]
  }
}

// ============================================================================
// NSG WITH INTENTIONALLY OPEN RULES (SRE Agent should detect these)
// ============================================================================
resource secure_nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'nsg-${resourceToken}'
  location: location
  tags: securedemoinfratags
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
resource secure_storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'st${resourceToken}'
  location: location
  tags: securedemoinfratags
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
  parent: secure_storageAccount
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
  tags: securedemoinfratags
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
  tags: securedemoinfratags
}

// ⚠️ INTENTIONALLY MISSING: No VNet link created
// This is the issue - the DNS zone exists but isn't linked to the VNet
// SRE Agent should detect this misconfiguration

// ============================================================================
// APP SERVICE: Working web app connected to VNet, Key Vault, and Storage
// The app works fine, but the infrastructure has security issues
// ============================================================================
resource secure_appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'plan-secure-${resourceToken}'
  location: location
  tags: securedemoinfratags
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
resource secure_webApp1 'Microsoft.Web/sites@2022-09-01' = {
  name: 'app-secure-${resourceToken}'
  location: location
  tags: union(tags, {
    'azd-service-name': 'api'
  })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: secure_appServicePlan.id
    virtualNetworkSubnetId: secure_vnet.properties.subnets[0].id  // snet-app with the insecure NSG
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
          value: secure_storageAccount.name
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
  parent: secure_webApp1
  name: 'vnet-connection'
  properties: {
    vnetResourceId: secure_vnet.properties.subnets[0].id
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
// var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' 

resource storageRoleAssignment1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(secure_storageAccount.id, secure_webApp1.id, storageBlobDataContributorRoleId)
  scope: secure_storageAccount
  properties: {
    principalId: secure_webApp1.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalType: 'ServicePrincipal'
  }
}


output MANAGED_IDENTITY_CLIENT_ID string = managedIdentity.properties.clientId
output MANAGED_IDENTITY_NAME string = managedIdentity.name
output MANAGED_IDENTITY_PRINCIPAL_ID string = managedIdentity.properties.principalId
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = logAnalyticsWorkspace.name
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = logAnalyticsWorkspace.id
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
output AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID string = managedIdentity.id
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.name
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = containerAppEnvironment.name
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = containerAppEnvironment.id
output AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN string = containerAppEnvironment.properties.defaultDomain
output vm1Name string = vm1.name
output vm2Name string = vm2.name
output orphanedDiskName string = orphanedDisk.name
output untaggedStorageName string = storageUntagged1.name
output webAppName string = secure_webApp1.name
output webAppUrl string = 'https://${secure_webApp1.properties.defaultHostName}'
output vnetName string = secure_vnet.name
output nsgName string = secure_nsg.name
output storageAccountName string = secure_storageAccount.name
output keyVaultName string = keyVault.name
output privateDnsZoneName string = privateDnsZone.name
output secureWebAppName string = secure_webApp1.name
output secureWebAppUrl string = 'https://${secure_webApp1.properties.defaultHostName}'
output secureWebAppPrincipalId string = secure_webApp1.identity.principalId
