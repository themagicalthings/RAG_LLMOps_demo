import rag.src.rag.backend.constants as constants
from fastapi import FastAPI
from rag.src.rag.backend.data_models import Prompt, RagResponse
from rag.src.rag.backend.agents import bot_answer
from rag.src.rag.backend.middleware import logging_middleware

app = FastAPI()
logging_middleware(app=app)

@app.get("/")
async def status():
    return {"status": "it works"}

@app.post("/rag/query")
async def query_documentation(query: Prompt) -> RagResponse:
    result = await bot_answer(query.prompt)

    return result