// modules/acr.bicep -- Azure Container Registry, Basic SKU with admin user.
//
// NOTE: admin user is enabled to match today's PS deploy. For prod, disable it
// and grant the consuming Container Apps a managed identity with AcrPull instead.

param acrName string
param location string
param tags object = {}

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: acrName
  location: location
  tags: tags
  sku: { name: 'Basic' }
  properties: {
    adminUserEnabled: true
  }
}

output name string = acr.name
output loginServer string = acr.properties.loginServer
output id string = acr.id
