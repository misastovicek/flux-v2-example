param location string = 'northeurope'
param name string
param cidrBlock string = '172.16.0.0/23'
param dockerBridgeCidr string = '172.20.0.1/16'
param dockerDnsIp string = '172.21.0.10'
param serviceCidr string = '172.21.0.0/16'
param aksNodecount int = 1
@allowed([
  'Standard_B2ms'
  'Standard_B4ms'
])
param aksNodeSize string = 'Standard_B2ms'
param publicSSHKey string

var role = {
  keyVaultCryptoUser: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/12338af0-0e69-4776-bea7-57ae8d297424'
  acrPull: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d'
  managedIdentityOperator: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/f1a07417-d97a-45cb-824c-7a7467783830'
}

resource Vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'vnet-${name}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        cidrBlock
      ]
    }
    subnets: [
      {
        name: 'snet-aks-${name}'
        properties: {
          addressPrefix: cidrBlock
        }
      }
    ]
  }
}

resource ContainerRegistry 'Microsoft.ContainerRegistry/registries@2019-05-01' = {
  name: name
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {}
}

resource AksCluster 'Microsoft.ContainerService/managedClusters@2021-03-01' = {
  name: 'aks-${name}'
  location: location
  sku: {
    name: 'Basic'
    tier: 'Free'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: 'aks-${name}'
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
    enableRBAC: true
    nodeResourceGroup: 'rg-${name}-aksnodes'
    linuxProfile: {
      adminUsername: name
      ssh: {
        publicKeys: [
          {
            keyData: publicSSHKey
          }
        ]
      }
    }
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      loadBalancerSku: 'basic'
      dockerBridgeCidr: dockerBridgeCidr
      serviceCidr: serviceCidr
      dnsServiceIP: dockerDnsIp
    }
    agentPoolProfiles: [
      {
        vmSize: aksNodeSize
        vnetSubnetID: '${Vnet.id}/subnets/snet-aks-${name}'
        osType: 'Linux'
        count: aksNodecount
        name: 'agentpool'
        enableAutoScaling: false
        mode: 'System'
      }
    ]
  }
  dependsOn: [
    Vnet
  ]
}

resource AksAcrPull 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('aksAcrPull', ContainerRegistry.id, resourceGroup().id)
  scope: ContainerRegistry
  properties: {
    roleDefinitionId: role['acrPull']
    principalId: AksCluster.identity.principalId
    description: 'Allow AKS to pull images from ACR'
  }
}

resource KubeletAksRgIdentityOperator 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('kubeletMsiOperator', AksCluster.id, resourceGroup().id)
  properties: {
    principalId: any(AksCluster.properties.identityProfile.kubeletidentity).objectId
    roleDefinitionId: role['managedIdentityOperator']
    description: 'Allow Kubelet to manage MSIs in AKS RG'
  }
}

resource MsiFluxCD 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'flux-cd'
  location: location
}

// Used for SOPS decryption 'flux-cd-keyvault-keys-access'
resource FluxCDKeyVaultKeysAccess 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(KeyVault.id, resourceGroup().id)
  scope: KeyVault
  properties: {
    roleDefinitionId: role['keyVaultCryptoUser']
    description: 'Allow Flux CD to use keys in KeyVault'
    principalId: MsiFluxCD.properties.principalId
  }
}

resource KeyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: 'kv-${name}-test'
  location: location
  properties: {
    createMode: 'default'
    enableSoftDelete: false
    enableRbacAuthorization: true
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
  }
}

resource KeyVaultSopsKey 'Microsoft.KeyVault/vaults/keys@2020-04-01-preview' = {
  name: 'sops'
  parent: KeyVault
  properties: {
    keySize: 2048
    kty: 'RSA'
    keyOps: [
      'decrypt'
      'encrypt'
    ]
  }
}

output keyVaultSopsKeyUri string = KeyVaultSopsKey.properties.keyUriWithVersion
output fluxMsiId string = MsiFluxCD.properties.clientId
output aksKubeletIdentityObjectId string = any(AksCluster.properties.identityProfile.kubeletidentity).objectId
output aksNodesResourceGroup string = AksCluster.properties.nodeResourceGroup
