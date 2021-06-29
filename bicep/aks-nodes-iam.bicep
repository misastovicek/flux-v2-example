param aksKubeletIdentityObjectId string

targetScope = 'resourceGroup'

var role = {
  reader: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'
  virtualMachineContributor: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
}

resource KubeletAksNodesRgReader 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('reader', resourceGroup().id)
  properties: {
    principalId: aksKubeletIdentityObjectId
    roleDefinitionId: role['reader']
    description: 'Allow Kubelet read over AKS Nodes RG'
  }
}

resource KubeletAksNodesRgVMSSContributor 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('vmssContributor', resourceGroup().id)
  properties: {
    principalId: aksKubeletIdentityObjectId
    roleDefinitionId: role['virtualMachineContributor']
    description: 'Allow Kubelet to manage VMs in AKS Nodes RG'
  }
}
