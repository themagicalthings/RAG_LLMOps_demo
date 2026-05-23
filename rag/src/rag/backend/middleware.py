from fastapi import FastAPI, Request
from starlette.responses import Response
from starlette.middleware.base import RequestResponseEndpoint
import time
import mlflow
from mlflow.tracking import MlflowClient

from rag.backend.constants import EXPERIMENT_NAME


def logging_middleware(app: FastAPI):
    client = MlflowClient()
    experiment = mlflow.get_experiment_by_name(EXPERIMENT_NAME)
    experiment_id = experiment.experiment_id if experiment else "0"

    @app.middleware("http")
    async def mlflow_middleware(
        request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        start_time = time.perf_counter()

        run = client.create_run(
            experiment_id=experiment_id,
            run_name=f"{request.method} {request.url.path}",
        )
        run_id = run.info.run_id

        try:
            response = await call_next(request)
            elapsed_time_seconds = time.perf_counter() - start_time

            client.log_metric(run_id, "status_code", response.status_code)
            client.log_metric(run_id, "latency_seconds", elapsed_time_seconds)

            for key, value in {
                "endpoint": request.url.path,
                "method": request.method,
                "is_error": response.status_code >= 400,
            }.items():
                client.log_param(run_id, key, value)

            for key, value in {
                "environment": "dev",
                "client_ip": request.client.host if request.client else "unknown",
                "method": request.method,
            }.items():
                client.set_tag(run_id, key, value)

            client.set_terminated(run_id, status="FINISHED")
        except Exception:
            client.set_terminated(run_id, status="FAILED")
            raise

        return response