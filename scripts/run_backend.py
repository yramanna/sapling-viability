from __future__ import annotations

"""CLI entrypoint for running the local FastAPI backend."""

import argparse
import sys
from pathlib import Path

import uvicorn

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def main() -> None:
    """Parse command-line flags and launch the backend server."""
    parser = argparse.ArgumentParser(description="Run the Bloomlogic local backend API.")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind. Default: 0.0.0.0")
    parser.add_argument("--port", type=int, default=8000, help="Port to bind. Default: 8000")
    args = parser.parse_args()

    uvicorn.run("src.backend.api:app", host=args.host, port=args.port, reload=False)


if __name__ == "__main__":
    main()
