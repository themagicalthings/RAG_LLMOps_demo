import llmops_project.part5.rag.backend.constants as constants
from fastapi import FastAPI
from llmops_project.part5.rag.backend.data_models import Prompt, RagResponse
from llmops_project.part5.rag.backend.agents import bot_answer
from llmops_project.part5.rag.backend.middleware import logging_middleware

app = FastAPI()
logging_middleware(app=app)

@app.get("/")
async def status():
    return {"status": "it works"}

@app.post("/rag/query")
async def query_documentation(query: Prompt) -> RagResponse:
    result = await bot_answer(query.prompt)

    return result