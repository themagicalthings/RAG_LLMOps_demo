# Bicep-based Azure deployment

Same Azure resources as [`../azure/`](../azure/) (imperative `az` scripts), but declared in **Bicep** and provisioned by ARM. Use this as the recording-ready, IaC-style deploy path.

## Architecture (unchanged)

- Resource Group `rag-llmops-rg` (eastus)
- ACR `ragllmops170510` (Basic, admin-enabled)
- Log Analytics workspace `rag-logs`
- Container Apps Environment `rag-env`
- MLflow Container App `rag-mlflow` (public `ghcr.io/mlflow/mlflow:latest`, ephemeral SQLite)
- Container Apps Job `rag-prompt-init` (Manual trigger; backend image; registers prompts)
- Backend Container App `rag-backend` (FastAPI; secrets for Cohere + OpenRouter; MLflow URL env)
- App Service Plan `rag-asp` (Linux B1)
- Web App `rag-frontend-170510` (Streamlit container; `WEBSITES_PORT=8501`; WebSockets on; AlwaysOn)

## File layout

```
infra/
  bootstrap.bicep          # SUB scope: creates RG + ACR
  main.bicep               # RG scope: env + mlflow + job + backend + frontend
  modules/
    acr.bicep
    container-env.bicep
    mlflow.bicep
    prompt-init-job.bicep
    backend.bicep
    frontend.bicep
  deploy/
    config.ps1             # shared names + helpers (same as azure/config.ps1)
    01-bootstrap.ps1       # az deployment sub create bootstrap.bicep
    02-build-push.ps1      # docker buildx --platform linux/amd64 --push (Bicep cannot do this)
    03-deploy.ps1          # az deployment group create main.bicep
    04-prompt-init.ps1     # az containerapp job start + wait (Bicep cannot do this)
    05-smoke-test.ps1      # curl backend + RAG question
    deploy-all.ps1         # runs 01..05
    teardown.ps1           # az group delete
```

## Bicep CLI version

**Pin Bicep CLI to `v0.32.4`** (or any v0.30.x–v0.34.x stable). The v0.43.x line has a known internal-NullRef/AccessViolation bug on Windows when compiling files that use `module` references — both `bootstrap.bicep` and `main.bicep` trigger it.

```pwsh
az bicep install --version v0.32.4
az bicep version    # should print 0.32.4
```

You can ignore the "newer Bicep available" warnings — that's the broken version.

## Quick start

```pwsh
cd infra/deploy
./deploy-all.ps1
```

Or stage-by-stage for recording:

```pwsh
./01-bootstrap.ps1     # RG + ACR via bootstrap.bicep            (~1 min)
./02-build-push.ps1    # docker buildx amd64 push                 (~5-10 min first time)
./03-deploy.ps1        # everything else via main.bicep           (~3-5 min)
./04-prompt-init.ps1   # az containerapp job start + poll         (~1-2 min)
./05-smoke-test.ps1    # poll endpoints + POST a real question    (~1 min)
```

## What Bicep does vs what stays imperative

| Step | How |
|------|-----|
| Create RG + ACR | **Bicep** (`bootstrap.bicep`, subscription scope) |
| Build + push images | **Imperative** (`docker buildx --push` — Bicep cannot drive Docker) |
| Provision Container Apps env + MLflow + Job + backend + Web App | **Bicep** (`main.bicep`, RG scope) |
| Trigger the prompt-init Job execution | **Imperative** (`az containerapp job start` — Bicep declares, does not execute) |
| Smoke-test live endpoints | **Imperative** (`Invoke-WebRequest` / `Invoke-RestMethod`) |

## Why 2 deployments (not 1)

Container Apps in `main.bicep` reference an image like `<acr>.azurecr.io/rag-backend:v1`. If the image isn't in ACR yet, the Container App fails to start. So:

1. **`bootstrap.bicep`** must run first → ACR exists.
2. **`02-build-push.ps1`** then pushes images into the ACR.
3. **`main.bicep`** then provisions everything else with valid image references.

## Secrets

Today's flow reads `COHERE_API_KEY` + `OPENROUTER_API_KEY` from your local `rag/src/rag/.env` and passes them to Bicep as `@secure()` parameters in `03-deploy.ps1`. They get written into Container App secrets and surfaced as env vars via `secretRef`.

For a real environment, point these `@secure()` params at **Azure Key Vault** references instead — same Bicep, different parameter source.

## Persistence

MLflow uses SQLite on **ephemeral** Container Apps storage (same as the imperative deploy). Restart = data wiped → re-run `04-prompt-init.ps1` to re-register prompts. For real persistence, swap to **Azure Database for PostgreSQL** + Azure Blob artifact store inside `modules/mlflow.bicep`.

## Validate before deploying

```pwsh
az bicep build --file infra/bootstrap.bicep
az bicep build --file infra/main.bicep

# Preview changes against your subscription without applying:
az deployment sub what-if `
  --location eastus `
  --template-file infra/bootstrap.bicep `
  --parameters location=eastus resourceGroupName=rag-llmops-rg acrName=ragllmops170510

# After RG exists, preview changes to the RG:
az deployment group what-if `
  --resource-group rag-llmops-rg `
  --template-file infra/main.bicep `
  --parameters @<your-params>
```

`what-if` is the killer feature over the imperative scripts: shows you exactly which Azure resources will change *before* you apply.

## Teardown

```pwsh
./teardown.ps1
```

Type the RG name to confirm; deletes everything in the background.
