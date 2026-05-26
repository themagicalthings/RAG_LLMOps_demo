from pydantic_ai import Agent

from rag.backend.constants import VECTOR_DB_PATH, MODEL
import lancedb
from rag.backend.data_models import RagResponse
from mlflow.genai import load_prompt
import mlflow
from pydantic_ai.usage import UsageLimits

vector_db = lancedb.connect(uri=VECTOR_DB_PATH)


@mlflow.trace(span_type="RETRIEVER")
def _retrieve(query: str, k: int) -> list[dict]:
    results = vector_db["articles"].search(query=query).limit(k).to_list()
    return [
        {
            "page_content": result["content"],
            "metadata": {
                "source": result.get("document_name", ""),
                "filepath": result.get("filepath", ""),
            },
        }
        for result in results
    ]


def _build_rag_agent() -> Agent:
    """Construct the RAG agent. Called lazily so a missing/unreachable MLflow
    prompt doesn't crash the FastAPI import."""
    agent = Agent(
        model=MODEL,
        system_prompt=load_prompt("rag_agent_system_prompt").format(
            num_sentences=4, max_sentences=4
        ),
        output_type=RagResponse,
    )

    @agent.tool_plain
    def retrieve_top_documents(query: str, k: int = 3) -> str:
        """retrieves top k documents"""
        k = int(k)
        results = _retrieve(query, k)
        return "\n\n".join(
            f"""Filename: {result["metadata"]["source"]}\
            Filepath: {result["metadata"]["filepath"]}\
            Content: {result["page_content"]}"""
            for result in results
        )

    return agent


# Try to build at import time so the first request is fast. If MLflow / prompts
# aren't ready, leave it None and retry on first request.
try:
    rag_agent: Agent | None = _build_rag_agent()
except Exception as exc:
    print(f"[agents] could not build agent at import time: {exc!r}")
    rag_agent = None


@mlflow.trace
async def bot_answer(question: str) -> RagResponse:
    global rag_agent
    if rag_agent is None:
        try:
            rag_agent = _build_rag_agent()
        except Exception as exc:
            return RagResponse(
                filename=None,
                filepath=None,
                answer=f"agent not ready (MLflow or prompts unavailable): {exc}",
            )

    try:
        result = await rag_agent.run(
            question, usage_limits=UsageLimits(request_limit=10)
        )
        return result.output
    except Exception as exc:
        return RagResponse(
            filename=None,
            filepath=None,
            answer=f"agent stopped early: {exc}",
        )
