from pydantic_ai import Agent

from rag.backend.constants import VECTOR_DB_PATH, MODEL
import lancedb
from rag.backend.data_models import RagResponse
from mlflow.genai import load_prompt
import mlflow
from pydantic_ai.usage import UsageLimits

vector_db = lancedb.connect(uri=VECTOR_DB_PATH)

rag_agent = Agent(
    model=MODEL,
    system_prompt=load_prompt("rag_agent_system_prompt").format(
        num_sentences=4, max_sentences=4
    ),
    output_type=RagResponse,
)


@rag_agent.tool_plain
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


@mlflow.trace
async def bot_answer(question: str) -> RagResponse:
    try:
        result = await rag_agent.run(
            question, usage_limits=UsageLimits(request_limit=10)
        )
        return result.output
    except Exception as e:
        return RagResponse(
            filename=None,
            filepath=None,
            answer=f"agent stopped early: {e}",
        )