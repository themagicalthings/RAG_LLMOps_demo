from pathlib import Path
import mlflow
import os

ROOT_PATH = Path(__file__).parents[1]
DATA_PATH = ROOT_PATH / "data"
PROMPTS_PATH = ROOT_PATH / "prompt_engineering"
VECTOR_DB_PATH = ROOT_PATH / "knowledge_base"

# from cohere
EMBEDDING_MODEL = "embed-multilingual-light-v3.0"

MODEL = "openrouter:openai/gpt-4.1-nano"
LLM_JUDGE = "openrouter:openai/gpt-4.1-nano"

EXPERIMENT_NAME = "LLMops_RAG_Experiment"

MLFLOW_DB = os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5001")

# set_tracking_uri is a local config write -- safe at import.
mlflow.set_tracking_uri(MLFLOW_DB)

# set_experiment hits the MLflow server. If MLflow is unreachable or returns
# 403 (Host-header check), this raises and would crash the whole import. Wrap
# so the backend can still start; agents.py / bot_answer will retry lazily.
try:
    mlflow.set_experiment(EXPERIMENT_NAME)
except Exception as exc:
    print(f"[constants] mlflow.set_experiment({EXPERIMENT_NAME!r}) failed at import: {exc!r}")
