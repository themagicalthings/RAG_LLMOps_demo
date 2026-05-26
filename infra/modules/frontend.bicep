// modules/frontend.bicep -- Streamlit frontend on Container Apps.
//
// Replaces the App Service Plan + Web App pattern. Container Apps:
//   - has no VM quota dependency (App Service B1 needed 1 VM)
//   - supports WebSockets natively (transport: 'auto')
//   - shares the same Container Apps Environment as MLflow + backend
//   - scales to zero by default; we pin min=1 for instant-on demo

param name string
param location string
param environmentId string
param image string
param acrLoginServer string
param acrUsername string
@secure()
param acrPassword string
param backendUrl string
param tags object = {}

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: true
        targetPort: 8501
        transport: 'auto'
      }
      registries: [
        {
          server: acrLoginServer
          username: acrUsername
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        { name: 'acr-password', value: acrPassword }
      ]
    }
    template: {
      containers: [
        {
          name: 'frontend'
          image: image
          env: [
            { name: 'API_URL', value: backendUrl }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

output fqdn string = app.properties.configuration.ingress.fqdn
output name string = app.name
