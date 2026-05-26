// modules/backend.bicep -- FastAPI backend Container App with secrets + MLflow URL.

param name string
param location string
param environmentId string
param image string
param acrLoginServer string
param acrUsername string
@secure()
param acrPassword string
param mlflowUrl string
@secure()
param cohereApiKey string
@secure()
param openrouterApiKey string
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
        targetPort: 8000
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
        { name: 'acr-password',       value: acrPassword }
        { name: 'cohere-api-key',     value: cohereApiKey }
        { name: 'openrouter-api-key', value: openrouterApiKey }
      ]
    }
    template: {
      containers: [
        {
          name: 'backend'
          image: image
          env: [
            { name: 'COHERE_API_KEY',     secretRef: 'cohere-api-key' }
            { name: 'OPENROUTER_API_KEY', secretRef: 'openrouter-api-key' }
            { name: 'MLFLOW_TRACKING_URI', value: mlflowUrl }
            { name: 'GIT_PYTHON_REFRESH', value: 'quiet' }
          ]
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
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
