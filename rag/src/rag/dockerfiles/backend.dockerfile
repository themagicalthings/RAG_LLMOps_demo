FROM python:3.13-slim

# Pull the uv binary from its official image (no `pip install uv` -> no
# amd64-emulation segfault on buildx).
COPY --from=ghcr.io/astral-sh/uv:0.5.4 /uv /uvx /usr/local/bin/

WORKDIR /app/rag

COPY knowledge_base knowledge_base
COPY backend backend
COPY prompt_engineering prompt_engineering

ENV PYTHONPATH=/app

WORKDIR /app/rag/backend

# Resolve + install deps into /app/rag/backend/.venv.
RUN uv sync --no-dev

# Put the venv binaries first on PATH so runtime calls don't need `uv run`.
# `uv run` does a fresh dep check on every invocation; since the workspace
# uv.lock isn't in the build context, that re-check can re-write packages
# and corrupt files. Direct venv binaries avoid this entirely.
ENV PATH="/app/rag/backend/.venv/bin:${PATH}"

CMD ["uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8000"]
