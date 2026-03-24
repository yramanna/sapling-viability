from __future__ import annotations

from pathlib import Path
from uuid import uuid4

from fastapi import FastAPI, File, HTTPException, Request, UploadFile
from fastapi.staticfiles import StaticFiles

from src.backend.service import TrayAnalysisService, TrayAnalysisServiceConfig


def _artifact_url(request: Request, path: str | None, root: Path) -> str | None:
    if path is None:
        return None
    rel_path = Path(path).resolve().relative_to(root.resolve())
    return str(request.base_url).rstrip("/") + f"/artifacts/{rel_path.as_posix()}"


config = TrayAnalysisServiceConfig()
service = TrayAnalysisService(config=config)

app = FastAPI(title="Bloomlogic Tray Analysis API", version="0.1.0")
app.mount("/artifacts", StaticFiles(directory=str(config.output_dir)), name="artifacts")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/analyze-tray")
async def analyze_tray(request: Request, image: UploadFile = File(...)) -> dict:
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

    artifacts = result["artifacts"]
    result["artifacts"] = {
        "annotated_image_url": _artifact_url(request, artifacts["annotated_image_path"], config.output_dir),
        "rectified_image_url": _artifact_url(request, artifacts["rectified_image_path"], config.output_dir),
        "result_json_url": _artifact_url(request, artifacts["result_json_path"], config.output_dir),
    }
    return result
