@description('The location into which the virtual network resources should be deployed.')
param location string

@description('The IP address prefix (CIDR range) to use when deploying the virtual network.')
param vnetIPPrefix string

@description('The IP address prefix (CIDR range) to use when deploying the Application Gateway subnet within the virtual network.')
param applicationGatewaySubnetIPPrefix string

@description('The IP address prefix (CIDR range) to use when deploying the VM subnet within the virtual network.')
param vmSubnetIPPrefix string

var vnetName = 'VNet'
var applicationGatewaySubnetName = 'ApplicationGateway'
var vmSubnetName = 'VMs'
var nsgName = 'MyNSG'

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetIPPrefix
      ]
    }
    subnets: [
      {
        name: applicationGatewaySubnetName
        properties: {
          addressPrefix: applicationGatewaySubnetIPPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: vmSubnetName
        properties: {
          addressPrefix: vmSubnetIPPrefix
        }
      }
    ]
  }

  resource applicationGatewaySubnet 'subnets' existing = {
    name: applicationGatewaySubnetName
  }

  resource vmSubnet 'subnets' existing = {
    name: vmSubnetName
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow_inbound_HTTP_and_HTTPS_traffic'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '80'
            '443'
          ]
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }

      // Rules for Application Gateway as documented here: https://docs.microsoft.com/en-us/azure/application-gateway/application-gateway-faq
      {
        name: 'Allow_GWM'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow_AzureLoadBalancer'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

output vnetName string = vnetName
output applicationGatewaySubnetResourceId string = vnet::applicationGatewaySubnet.id
output vmSubnetResourceId string = vnet::vmSubnet.id
