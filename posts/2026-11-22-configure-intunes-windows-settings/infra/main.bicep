metadata name = 'DSC CSP adapter demo - virtual machine'
metadata description = 'A Windows 11 Enterprise virtual machine with no inbound rules. Azure Run Command runs dsc on it as SYSTEM.'

targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Name of the virtual machine. Windows limits it to 15 characters.')
@maxLength(15)
param vmName string = 'vm-dscdemo'

@description('Size of the virtual machine.')
param vmSize string = 'Standard_D2s_v5'

@description('Name of the local administrator.')
param adminUsername string = 'dscadmin'

@description('Password of the local administrator. It is only needed to create the account.')
@secure()
param adminPassword string

var suffix = uniqueString(resourceGroup().id)
var publicIpName = 'pip-${vmName}'
var subnetName = 'snet-vm'

// No security rules of its own, so nothing from the internet reaches the virtual machine.
module networkSecurityGroup 'br/public:avm/res/network/network-security-group:0.5.4' = {
  name: 'nsg-${suffix}'
  params: {
    name: 'nsg-${vmName}'
    location: location
  }
}

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.10.2' = {
  name: 'vnet-${suffix}'
  params: {
    name: 'vnet-dscdemo'
    location: location
    addressPrefixes: [
      '10.20.0.0/24'
    ]
    subnets: [
      {
        name: subnetName
        addressPrefix: '10.20.0.0/26'
        networkSecurityGroupResourceId: networkSecurityGroup.outputs.resourceId
      }
    ]
  }
}

module virtualMachine 'br/public:avm/res/compute/virtual-machine:0.22.3' = {
  name: 'vm-${suffix}'
  params: {
    name: vmName
    location: location
    osType: 'Windows'
    vmSize: vmSize
    // No zone pinning, so the demo deploys in regions and subscriptions without zone capacity.
    availabilityZone: -1
    adminUsername: adminUsername
    adminPassword: adminPassword
    // A client edition: the MDM Bridge classes are not supported on Windows Server.
    imageReference: {
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'windows-11'
      sku: 'win11-24h2-ent'
      version: 'latest'
    }
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    nicConfigurations: [
      {
        nicSuffix: '-nic-01'
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: virtualNetwork.outputs.subnetResourceIds[0]
            // The public IP address is the way out, to download dsc. Nothing comes in through it.
            pipConfiguration: {
              name: publicIpName
              skuName: 'Standard'
              publicIPAllocationMethod: 'Static'
              availabilityZones: []
            }
          }
        ]
      }
    ]
  }
}
