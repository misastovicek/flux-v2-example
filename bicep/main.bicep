param location string
param name string
param publicSSHKey string

targetScope = 'subscription'

resource aksRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${name}-aks'
  location: location
}

module AksResources 'components.bicep' = {
  name: 'aks-resources'
  params: {
    name: name
    publicSSHKey: publicSSHKey
  }
  scope: aksRG
}

module AksIAM 'aks-nodes-iam.bicep' = {
  name: 'aks-nodes-iam'
  params: {
    aksKubeletIdentityObjectId: AksResources.outputs.aksKubeletIdentityObjectId
  }
  scope: resourceGroup('rg-${name}-aksnodes')
}
