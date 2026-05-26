FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

WORKDIR /app/rag

COPY frontend frontend

ENV PYTHONPATH=/app

WORKDIR /app/rag/frontend

RUN uv sync --no-dev

CMD ["uv", "run", "streamlit", "run", "app.py", "--server.address", "0.0.0.0", "--server.port", "8501"]
