# Azure deployment

End-to-end automation for deploying the RAG demo to Azure:
- **ACR** for Docker images
- **Container Apps** for MLflow + FastAPI backend + the one-shot prompt-registration job
- **App Service for Containers** (Linux, B1) for the Streamlit frontend

Everything lives in one resource group so teardown is one command.

## Prerequisites

Run once on your workstation:

1. **Azure CLI** logged in: `az login` (verified via `az account show`)
2. **Docker Desktop** running with buildx (you have v0.20+)
3. **Cohere + OpenRouter API keys** present in `rag/src/rag/.env`:
   ```
   COHERE_API_KEY=...
   OPENROUTER_API_KEY=...
   ```
4. **Local ingestion already run** so the vector DB is on disk:
   ```pwsh
   cd rag/src/rag
   uv run python -m rag.setup.ingestion
   # produces knowledge_base/articles.lance
   ```

## Quick start

```pwsh
cd azure
./deploy-all.ps1
```

Takes ~15 minutes end-to-end. Smoke test at the end asks the deployed backend a real question; if it returns an answer + filepath you're done.

## Step-by-step (for recording)

| Step | What it does | Time |
|------|--------------|------|
| `01-acr.ps1`            | Creates RG + ACR, captures admin creds into `.env` | ~1 min |
| `02-build-push.ps1`     | `docker buildx --platform linux/amd64` + push both images | ~5–10 min (first time) |
| `03-deploy-mlflow.ps1`  | Container Apps env + MLflow app, saves MLflow URL to `.env` | ~2 min |
| `04-prompt-init.ps1`    | Creates and runs a one-shot Container Apps Job that registers prompts | ~2 min |
| `05-deploy-backend.ps1` | Backend Container App with secrets + MLflow URL | ~2 min |
| `06-deploy-frontend.ps1`| App Service plan + Web App + env vars + WebSockets on | ~2 min |
| `07-smoke-test.ps1`     | Polls all three URLs, then POSTs a real question | ~1 min |

Each script is **idempotent** — re-run any step without harm.

All names and the region are in `config.ps1` — change them there if you need a different RG / region / app names.

## What gets written to `.env`

Scripts append (or update in place) these keys:

| Key | Set by |
|-----|--------|
| `ACR_NAME`, `ACR_LOGIN_SERVER`, `ACR_USERNAME`, `ACR_PASSWORD` | `01-acr.ps1` |
| `MLFLOW_TRACKING_URI` (e.g. `https://rag-mlflow.<env>.eastus.azurecontainerapps.io`) | `03-deploy-mlflow.ps1` |
| `BACKEND_URL`  | `05-deploy-backend.ps1` |
| `FRONTEND_URL` | `06-deploy-frontend.ps1` |

These are read by later scripts and the smoke test.

## Persistence note (read before you ship to prod)

MLflow runs with `sqlite:////mlflow/mlflow.db` on **ephemeral** Container Apps storage. On every restart, experiment history and registered prompts are wiped. That's why `04-prompt-init.ps1` is part of the deploy flow — re-run it if you bounce MLflow.

For a real environment, replace the SQLite store with **Azure Database for PostgreSQL** or mount **Azure Files** at `/mlflow`, and point `--default-artifact-root` at an Azure Blob container.

## Teardown

```pwsh
./teardown.ps1
```

Asks you to type the resource group name to confirm, then deletes everything in the background. After teardown you can rebuild from scratch with `./deploy-all.ps1`.

## Troubleshooting

- **"NOT_INSTALLED" / `containerapp` extension** — `01-acr.ps1` installs it automatically; if you ran scripts out of order, `az extension add --name containerapp --upgrade` once.
- **ACR name already taken** — change `$AcrName` in `config.ps1` and re-run.
- **Web App name already taken** — change `$WebApp` in `config.ps1` and re-run.
- **Frontend returns blank page** — the backend may still be cold-starting; the smoke test allows up to ~2.5 min of retries.
- **Backend logs** —
  ```pwsh
  az containerapp logs show -n rag-backend -g rag-llmops-rg --follow
  ```
- **Frontend logs** —
  ```pwsh
  az webapp log tail -n rag-frontend-170510 -g rag-llmops-rg
  ```
- **prompt-init job logs** —
  ```pwsh
  az containerapp job execution list -n rag-prompt-init -g rag-llmops-rg -o table
  az containerapp job execution show  -n rag-prompt-init -g rag-llmops-rg --job-execution-name <name-from-above>
  ```
