from __future__ import annotations

"""FastAPI wrapper for the local tray-analysis backend."""

from pathlib import Path
from uuid import uuid4

from fastapi import FastAPI, File, HTTPException, Request, UploadFile
from fastapi.staticfiles import StaticFiles

from src.backend.service import TrayAnalysisService, TrayAnalysisServiceConfig


def _artifact_url(request: Request, path: str | None, root: Path) -> str | None:
    """Convert an artifact path on disk into a public URL."""
    if path is None:
        return None
    rel_path = Path(path).resolve().relative_to(root.resolve())
    return str(request.base_url).rstrip("/") + f"/artifacts/{rel_path.as_posix()}"


def _artifact_urls(request: Request, artifacts: dict[str, str | None], root: Path) -> dict[str, str | None]:
    """Build the artifact URL payload returned to API clients."""
    return {
        "annotated_image_url": _artifact_url(request, artifacts["annotated_image_path"], root),
        "rectified_image_url": _artifact_url(request, artifacts["rectified_image_path"], root),
        "result_json_url": _artifact_url(request, artifacts["result_json_path"], root),
    }


config = TrayAnalysisServiceConfig()
service = TrayAnalysisService(config=config)

app = FastAPI(title="Bloomlogic Tray Analysis API", version="0.1.0")
app.mount("/artifacts", StaticFiles(directory=str(config.output_dir)), name="artifacts")


@app.get("/health")
def health() -> dict[str, str]:
    """Return a simple readiness response."""
    return {"status": "ok"}


@app.post("/analyze-tray")
async def analyze_tray(request: Request, image: UploadFile = File(...)) -> dict:
    """Analyze one uploaded tray image and return artifact URLs plus results."""
    suffix = Path(image.filename or "upload.jpg").suffix or ".jpg"
    upload_name = f"{uuid4().hex}{suffix}"
    upload_path = service.upload_dir / upload_name

    contents = await image.read()
    if not contents:
        raise HTTPException(status_code=400, detail="Uploaded image is empty.")

    upload_path.write_bytes(contents)
    try:
        result = service.analyze_image(upload_path)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    result["artifacts"] = _artifact_urls(request, result["artifacts"], config.output_dir)
    return result
