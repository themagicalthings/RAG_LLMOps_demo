FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

WORKDIR /app/rag

COPY knowledge_base knowledge_base
COPY backend backend
COPY prompt_engineering prompt_engineering

ENV PYTHONPATH=/app

WORKDIR /app/rag/backend

RUN uv sync --no-dev

CMD ["uv", "run", "uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8000"]