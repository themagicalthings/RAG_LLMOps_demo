from llmops_project.part5.rag.backend.constants import PROMPTS_PATH
from mlflow.genai import register_prompt


def register_prompts(**kwargs):
    for filepath in PROMPTS_PATH.glob("*.md"):
        with open(filepath) as file:
            filename = filepath.stem
            prompt = file.read()
        
        register_prompt(name = filename, template=prompt, **kwargs)


if __name__ == "__main__":
    register_prompts(tags = {"author": "kokchun", "stage": "dev"})