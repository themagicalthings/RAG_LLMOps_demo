// main.bicep -- Resource-group-scope deployment of the runtime stack.
//
// Assumes bootstrap.bicep already ran (RG + ACR exist) and 02-build-push.ps1
// has pushed the backend + frontend images to ACR.
//
// Deploy:
//   az deployment group create --resource-group <rg> \
//     --template-file infra/main.bicep \
//     --parameters acrName=<acr> acrUsername=<u> acrPassword=<p> \
//                  cohereApiKey=<...> openrouterApiKey=<...> \
//                  webAppName=<unique>

targetScope = 'resourceGroup'

// --- Naming --------------------------------------------------------------
@description('Azure region.')
param location string = resourceGroup().location

@description('Name of the existing ACR (created by bootstrap.bicep).')
param acrName string

@description('ACR admin username (from `az acr credential show`).')
param acrUsername string

@description('ACR admin password (from `az acr credential show`).')
@secure()
param acrPassword string

@description('Container Apps Environment name.')
param envName string = 'rag-env'

@description('Log Analytics workspace name.')
param logAnalyticsName string = 'rag-logs'

@description('MLflow Container App name.')
param mlflowAppName string = 'rag-mlflow'

@description('Backend Container App name.')
param backendAppName string = 'rag-backend'

@description('Prompt-init Container Apps Job name.')
param promptInitJobName string = 'rag-prompt-init'

@description('Frontend Container App name.')
param frontendAppName string = 'rag-frontend'

@description('Image tag for backend (e.g. v1, or git SHA).')
param backendImageTag string = 'v1'

@description('Image tag for frontend.')
param frontendImageTag string = 'v1'

// --- Secrets -------------------------------------------------------------
@secure()
param cohereApiKey string

@secure()
param openrouterApiKey string

// --- Tags ----------------------------------------------------------------
param tags object = {
  project: 'rag-llmops-demo'
  managedBy: 'bicep'
}

// ACR login server has a deterministic format. Avoid an `existing` lookup so
// we don't trigger a Bicep CLI 0.43.8 NullRef bug in the type loader.
var acrLoginServer = '${acrName}.azurecr.io'
var backendImage   = '${acrLoginServer}/rag-backend:${backendImageTag}'
var frontendImage  = '${acrLoginServer}/rag-frontend:${frontendImageTag}'

// --- Container Apps Environment + Log Analytics --------------------------
module env 'modules/container-env.bicep' = {
  name: 'env-deploy'
  params: {
    envName: envName
    logAnalyticsName: logAnalyticsName
    location: location
    tags: tags
  }
}

// --- MLflow ---------------------------------------------------------------
module mlflow 'modules/mlflow.bicep' = {
  name: 'mlflow-deploy'
  params: {
    name: mlflowAppName
    location: location
    environmentId: env.outputs.environmentId
    tags: tags
  }
}

// --- Backend Container App ------------------------------------------------
module backend 'modules/backend.bicep' = {
  name: 'backend-deploy'
  params: {
    name: backendAppName
    location: location
    environmentId: env.outputs.environmentId
    image: backendImage
    acrLoginServer: acrLoginServer
    acrUsername: acrUsername
    acrPassword: acrPassword
    mlflowUrl: 'https://${mlflow.outputs.fqdn}'
    cohereApiKey: cohereApiKey
    openrouterApiKey: openrouterApiKey
    tags: tags
  }
}

// --- Prompt-init Job (manual trigger; wrapper script runs it) -----------
module promptInit 'modules/prompt-init-job.bicep' = {
  name: 'promptinit-deploy'
  params: {
    name: promptInitJobName
    location: location
    environmentId: env.outputs.environmentId
    image: backendImage
    acrLoginServer: acrLoginServer
    acrUsername: acrUsername
    acrPassword: acrPassword
    mlflowUrl: 'https://${mlflow.outputs.fqdn}'
    tags: tags
  }
}

// --- Frontend (Container App on the same env as backend + MLflow) -------
module frontend 'modules/frontend.bicep' = {
  name: 'frontend-deploy'
  params: {
    name: frontendAppName
    location: location
    environmentId: env.outputs.environmentId
    image: frontendImage
    acrLoginServer: acrLoginServer
    acrUsername: acrUsername
    acrPassword: acrPassword
    backendUrl: 'https://${backend.outputs.fqdn}'
    tags: tags
  }
}

// --- Outputs (consumed by the smoke-test wrapper) ------------------------
output mlflowUrl  string = 'https://${mlflow.outputs.fqdn}'
output backendUrl string = 'https://${backend.outputs.fqdn}'
output frontendUrl string = 'https://${frontend.outputs.fqdn}'
output promptInitJobName string = promptInit.outputs.name
