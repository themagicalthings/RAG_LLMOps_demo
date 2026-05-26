// modules/mlflow.bicep -- MLflow tracking server on Container Apps.
//
// Uses the public ghcr.io/mlflow/mlflow image (no ACR pull credentials needed).
// SQLite backend store is EPHEMERAL on Container Apps storage.

param name string
param location string
param environmentId string
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
        targetPort: 5000
        transport: 'auto'
      }
    }
    template: {
      containers: [
        {
          name: 'mlflow'
          image: 'ghcr.io/mlflow/mlflow:latest'
          command: [ 'mlflow' ]
          args: [
            'server'
            '--host'
            '0.0.0.0'
            '--port'
            '5000'
            '--backend-store-uri'
            'sqlite:////mlflow/mlflow.db'
            // MLflow rejects requests whose Host header isn't in this list
            // (DNS-rebinding protection). Container Apps gives the app a random
            // *.azurecontainerapps.io FQDN, so we accept any host.
            '--allowed-hosts'
            '*'
          ]
          env: [
            { name: 'MLFLOW_SERVER_CORS_ALLOWED_ORIGINS', value: '*' }
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
