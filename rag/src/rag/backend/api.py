import rag.backend.constants as constants
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from rag.backend.data_models import Prompt, RagResponse
from rag.backend.agents import bot_answer
from rag.backend.middleware import logging_middleware

app = FastAPI()

# CORS: allow the Streamlit frontend (and /docs Swagger UI) to call this API.
# In prod, replace ["*"] with the explicit frontend origin.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

logging_middleware(app=app)

@app.get("/")
async def status():
    return {"status": "it works"}

@app.post("/rag/query")
async def query_documentation(query: Prompt) -> RagResponse:
    result = await bot_answer(query.prompt)

    return result
