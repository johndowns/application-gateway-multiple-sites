@description('The location into which the Application Gateway resources should be deployed.')
param location string

@description('The domain name label to attach to the Application Gateway\'s public IP address. This must be unique within the specified location.')
param publicIPAddressDomainNameLabel string = 'appgw${uniqueString(resourceGroup().id)}'

@description('The minimum number of capacity units for the Application Gateway to use when autoscaling.')
param minimumCapacity int = 2

@description('The maximum number of capacity units for the Application Gateway to use when autoscaling.')
param maximumCapacity int = 10

@description('The resource ID of the virtual network subnet that the Application Gateway should be deployed into.')
param subnetResourceId string

@description('The externally facing host name for application 1.')
param app1ExternalHostName string

@description('The externally facing host name for application 2.')
param app2ExternalHostName string

@description('The internal (private) IP address for the application server for application 1.')
param app1BackendIPAddress string

@description('The internal (private) IP address for the application server for application 2.')
param app2BackendIPAddress string

@description('The resource ID of a user-assigned managed identity that has access to the SSL certificate Key Vault secret.')
param userAssignedIdentityResourceId string

@secure()
@description('The base 64-encoded value of the wildcard SSL certificate. It\'s good practice to provide this by using a Key Vault reference.')
param sslCertificateData string

@secure()
@description('The password for the wildcard SSL certificate. It\'s good practice to provide this by using a Key Vault reference.')
param sslCertificatePassword string

var publicIPAddressName = 'MyApplicationGateway-PIP'
var applicationGatewayName = 'MyApplicationGateway'
var gatewayIPConfigurationName = 'MyGatewayIPConfiguration'
var frontendIPConfigurationName = 'MyFrontendIPConfiguration'
var frontendPort = 443
var frontendPortName = 'HttpsFrontendPort'
var backendPort = 80
var backendHttpSettingName = 'MyBackendHttpSetting'
var app1BackendAddressPoolName = 'App1BackendAddressPool'
var app2BackendAddressPoolName = 'App2BackendAddressPool'
var app1HttpListenerName = 'App1HttpListener'
var app2HttpListenerName = 'App2HttpListener'
var app1RequestRoutingRuleName = 'App1RequestRoutingRule'
var app2RequestRoutingRuleName = 'App2RequestRoutingRule'
var sslCertificateName = 'WildcardSslCertificate'
var wafPolicyName = 'MyWAFPolicy'
var wafPolicyManagedRuleSetType = 'OWASP'
var wafPolicyManagedRuleSetVersion = '3.1'

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: publicIPAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: publicIPAddressDomainNameLabel
    }
  }
}

resource applicationGateway 'Microsoft.Network/applicationGateways@2021-02-01' = {
  name: applicationGatewayName
  location: location
  identity:{
    type: 'UserAssigned'
    userAssignedIdentities:{
      '${userAssignedIdentityResourceId}' : {}
    }
  }
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    autoscaleConfiguration: {
      minCapacity: minimumCapacity
      maxCapacity: maximumCapacity
    }
    sslCertificates: [
      {
        name: sslCertificateName
        properties: {
          data: sslCertificateData
          password: sslCertificatePassword
        }
      }
    ]
    gatewayIPConfigurations: [
      {
        name: gatewayIPConfigurationName
        properties: {
          subnet: {
            id: subnetResourceId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: frontendIPConfigurationName
        properties: {
          publicIPAddress: {
            id: publicIPAddress.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: frontendPortName
        properties: {
          port: frontendPort
        }
      }
    ]
    backendAddressPools: [
      {
        name: app1BackendAddressPoolName
        properties: {
          backendAddresses: [
            {
              ipAddress: app1BackendIPAddress
            }
          ]
        }
      }
      {
        name: app2BackendAddressPoolName
        properties: {
          backendAddresses: [
            {
              ipAddress: app2BackendIPAddress
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: backendHttpSettingName
        properties: {
          port: backendPort
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
        }
      }
    ]
    httpListeners: [
      {
        name: app1HttpListenerName
        properties: {
          hostName: app1ExternalHostName
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, frontendIPConfigurationName)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, frontendPortName)
          }
          firewallPolicy: {
            id: wafPolicy.id
          }
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', applicationGatewayName, sslCertificateName)
          }
          protocol: 'Https'
        }
      }
      {
        name: app2HttpListenerName
        properties: {
          hostName: app2ExternalHostName
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, frontendIPConfigurationName)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, frontendPortName)
          }
          firewallPolicy: {
            id: wafPolicy.id
          }
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', applicationGatewayName, sslCertificateName)
          }
          protocol: 'Https'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: app1RequestRoutingRuleName
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, app1HttpListenerName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, app1BackendAddressPoolName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, backendHttpSettingName)
          }
        }
      }
      {
        name: app2RequestRoutingRuleName
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, app2HttpListenerName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, app2BackendAddressPoolName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, backendHttpSettingName)
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetVersion: wafPolicyManagedRuleSetVersion
      ruleSetType: wafPolicyManagedRuleSetType
      requestBodyCheck: false
    }
    firewallPolicy: {
      id: wafPolicy.id
    }
  }
}

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2020-06-01' = {
  name: wafPolicyName
  location: location
  properties: {
    policySettings: {
      mode: 'Prevention'
      state: 'Enabled'
      requestBodyCheck: false
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: wafPolicyManagedRuleSetType
          ruleSetVersion: wafPolicyManagedRuleSetVersion
        }
      ]
    }
  }
}

output applicationGatewayResourceId string = applicationGateway.id
output publicIPAddressHostName string = publicIPAddress.properties.dnsSettings.fqdn
