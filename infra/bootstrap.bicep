// bootstrap.bicep -- Subscription-scope bootstrap.
//
// Creates the resource group + the ACR that holds the images.
// This MUST run before docker push (chicken-and-egg).
//
// Deploy:
//   az deployment sub create --location <region> \
//     --template-file infra/bootstrap.bicep \
//     --parameters location=<region> resourceGroupName=<rg> acrName=<acr>

targetScope = 'subscription'

@description('Azure region for the resource group and ACR.')
param location string

@description('Name of the resource group to create.')
param resourceGroupName string

@description('Globally-unique ACR name (5-50 lowercase alphanumeric).')
@minLength(5)
@maxLength(50)
param acrName string

@description('Tags applied to the resource group.')
param tags object = {
  project: 'rag-llmops-demo'
  managedBy: 'bicep'
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module acr 'modules/acr.bicep' = {
  scope: rg
  name: 'acr-deploy'
  params: {
    acrName: acrName
    location: location
    tags: tags
  }
}

output resourceGroupName string = rg.name
output acrLoginServer string = acr.outputs.loginServer
output acrName string = acr.outputs.name
