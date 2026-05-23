FROM python:3.13-slim

WORKDIR /app/rag

COPY frontend frontend

ENV PYTHONPATH=/app

RUN pip install --no-cache-dir uv

WORKDIR /app/rag/frontend

RUN uv sync --no-dev

CMD ["uv", "run", "streamlit", "run", "app.py", "--server.address", "0.0.0.0", "--server.port", "8501"]
