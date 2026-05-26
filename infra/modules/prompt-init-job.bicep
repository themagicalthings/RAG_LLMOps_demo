// modules/prompt-init-job.bicep -- Container Apps Job that registers MLflow prompts.
//
// Trigger type Manual. Bicep ONLY declares the job; the wrapper script triggers it
// via `az containerapp job start` after `az deployment group create` returns.

param name string
param location string
param environmentId string
param image string
param acrLoginServer string
param acrUsername string
@secure()
param acrPassword string
param mlflowUrl string
param tags object = {}

resource job 'Microsoft.App/jobs@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    environmentId: environmentId
    configuration: {
      triggerType: 'Manual'
      replicaTimeout: 600
      replicaRetryLimit: 1
      manualTriggerConfig: {
        parallelism: 1
        replicaCompletionCount: 1
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
          name: 'prompt-init'
          image: image
          command: [ 'uv' ]
          args: [
            'run'
            'python'
            '-m'
            'rag.prompt_engineering.register_prompts'
          ]
          env: [
            { name: 'MLFLOW_TRACKING_URI', value: mlflowUrl }
            { name: 'GIT_PYTHON_REFRESH', value: 'quiet' }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
        }
      ]
    }
  }
}

output name string = job.name
