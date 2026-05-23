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

mlflow.set_tracking_uri(MLFLOW_DB)
mlflow.set_experiment(EXPERIMENT_NAME)