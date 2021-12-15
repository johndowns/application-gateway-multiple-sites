@description('The location into which regionally scoped resources should be deployed. Note that Front Door is a global resource.')
param location string = resourceGroup().location

@description('The IP address prefix (CIDR range) to use when deploying the virtual network.')
param vnetIPPrefix string = '10.0.0.0/16'

@description('The IP address prefix (CIDR range) to use when deploying the Application Gateway subnet within the virtual network.')
param applicationGatewaySubnetIPPrefix string = '10.0.0.0/24'

@description('The IP address prefix (CIDR range) to use when deploying the VM subnet within the virtual network.')
param vmSubnetIPPrefix string = '10.0.1.0/24'

@description('The name of the SKU to use when creating the virtual machine.')
param vmSize string = 'Standard_DS1_v2'

@description('The name of the operating system to deploy on the virtual machine.')
@allowed([
  'Windows2016Datacenter'
  'Windows2019Datacenter'
])
param vmOSName string = 'Windows2019Datacenter'

@description('The type of disk and storage account to use for the virtual machine\'s OS disk.')
param vmOSDiskStorageAccountType string = 'StandardSSD_LRS'

@description('The administrator username to use for the virtual machine.')
param vmAdminUsername string

@description('The administrator password to use for the virtual machine.')
@secure()
param vmAdminPassword string

@description('The externally facing host name for application 1.')
param app1ExternalHostName string // e.g. app1.contoso.com.

@description('The externally facing host name for application 2.')
param app2ExternalHostName string // e.g. app2.contoso.com.

@description('The name of the Key Vault resource. This must be globally unique.')
param keyVaultName string = uniqueString(resourceGroup().id)

@secure()
@description('The base 64-encoded value of the wildcard SSL certificate.')
param sslCertificateData string // You can use the loadFileAsBase64('filename') function, or provide this in another way.

@secure()
@description('The password of the wildcard SSL certificate.')
param sslCertificatePassword string

var vmImageReference = {
  Windows2019Datacenter: {
    publisher: 'MicrosoftWindowsServer'
    offer: 'WindowsServer'
    sku: '2019-Datacenter'
    version: 'latest'
  }
  Windows2016Datacenter: {
    publisher: 'MicrosoftWindowsServer'
    offer: 'WindowsServer'
    sku: '2016-Datacenter'
    version: 'latest'
  }
}

var keyVaultSslCertificateDataSecretName = 'wildcard-ssl-data'
var keyVaultSslCertificatePasswordSecretName = 'wildcard-ssl-password'
var userAssignedIdentityName = 'ApplicationGateway'

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: userAssignedIdentityName
  location: location
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForTemplateDeployment: true
    tenantId: tenant().tenantId
    enableRbacAuthorization: true
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}

@description('This is the built-in Key Vault Secrets User role. See https://docs.microsoft.com/azure/key-vault/general/rbac-guide')
resource keyVaultSecretsUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: keyVault
  name: guid(keyVault.id, userAssignedIdentityName, keyVaultSecretsUserRoleDefinition.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleDefinition.id
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource sslCertificateDataSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: keyVault
  name: keyVaultSslCertificateDataSecretName
  properties: {
    value: sslCertificateData
  }
}

resource sslCertificatePasswordSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: keyVault
  name: keyVaultSslCertificatePasswordSecretName
  properties: {
    value: sslCertificatePassword
  }
}

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    vnetIPPrefix: vnetIPPrefix
    applicationGatewaySubnetIPPrefix: applicationGatewaySubnetIPPrefix
    vmSubnetIPPrefix: vmSubnetIPPrefix
  }
}

module vms 'modules/vm.bicep' = [for i in range(1,2): {
  name: 'VM-${i}'
  params: {
    vmName: 'VM-${i}'
    location: location
    subnetResourceId: network.outputs.vmSubnetResourceId
    vmImageReference: vmImageReference[vmOSName]
    vmSize: vmSize
    vmOSDiskStorageAccountType: vmOSDiskStorageAccountType
    vmAdminUsername: vmAdminUsername
    vmAdminPassword: vmAdminPassword
  }
}]

module applicationGateway 'modules/application-gateway.bicep' = {
  name: 'application-gateway'
  params: {
    location: location
    subnetResourceId: network.outputs.applicationGatewaySubnetResourceId
    app1BackendIPAddress: vms[0].outputs.privateIPAddress
    app1ExternalHostName: app1ExternalHostName
    app2BackendIPAddress: vms[1].outputs.privateIPAddress
    app2ExternalHostName: app2ExternalHostName
    sslCertificateData: keyVault.getSecret(sslCertificateDataSecret.name)
    sslCertificatePassword: keyVault.getSecret(sslCertificatePasswordSecret.name)
    userAssignedIdentityResourceId: userAssignedIdentity.id
  }
}

output applicationGatewayHostName string = applicationGateway.outputs.publicIPAddressHostName
