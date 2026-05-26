FROM python:3.13-slim

COPY --from=ghcr.io/astral-sh/uv:0.5.4 /uv /uvx /usr/local/bin/

WORKDIR /app/rag

COPY frontend frontend

ENV PYTHONPATH=/app

WORKDIR /app/rag/frontend

RUN uv sync --no-dev

# Direct venv binaries on PATH (see backend.dockerfile for rationale).
ENV PATH="/app/rag/frontend/.venv/bin:${PATH}"

CMD ["streamlit", "run", "app.py", "--server.address", "0.0.0.0", "--server.port", "8501"]
