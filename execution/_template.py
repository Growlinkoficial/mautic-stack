#!/usr/bin/env python3
"""
[Nome do Script]
================
Descrição breve: o que este script faz.

Args (CLI):
    --input  (str): Descrição do input principal
    --output (str): Destino do output (opcional)

Returns:
    Escreve resultado em .tmp/data/ e log em .tmp/logs/execution_YYYYMMDD.jsonl

Raises:
    ValueError: Quando o input é inválido
    requests.HTTPError: Quando a API retorna erro

Example:
    python execution/nome_do_script.py --input "valor"
"""

import argparse
import json
import logging
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# ── Config ─────────────────────────────────────────────────────────────────────
LOG_DIR = Path(".tmp/logs")
DATA_DIR = Path(".tmp/data")
LOG_DIR.mkdir(parents=True, exist_ok=True)
DATA_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger(__name__)


# ── Execution Log ───────────────────────────────────────────────────────────────
def log_execution(
    script_name: str,
    inputs: dict,
    outputs: dict,
    duration_seconds: float,
    status: str,
    error: str | None = None,
) -> None:
    """Append structured entry to daily execution log (JSONL format)."""
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "script_name": script_name,
        "inputs": inputs,
        "outputs": outputs,
        "duration_seconds": round(duration_seconds, 3),
        "status": status,
        "error": error,
    }
    log_file = LOG_DIR / f"execution_{datetime.now().strftime('%Y%m%d')}.jsonl"
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry) + "\n")


# ── Main Logic ──────────────────────────────────────────────────────────────────
def run(input_value: str) -> dict[str, Any]:
    """
    Core logic of the script.

    Args:
        input_value: The primary input to process.

    Returns:
        dict with result summary.

    Raises:
        ValueError: If input_value is empty.
    """
    if not input_value:
        raise ValueError("input_value cannot be empty")

    # TODO: implement logic here
    logger.info(f"Processing: {input_value}")

    result = {"records": 0, "status": "ok"}
    return result


# ── CLI Entry Point ─────────────────────────────────────────────────────────────
def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, help="Input value to process")
    args = parser.parse_args()

    start = datetime.now()
    try:
        result = run(args.input)
        duration = (datetime.now() - start).total_seconds()
        log_execution(
            script_name=Path(__file__).name,
            inputs={"input": args.input},
            outputs=result,
            duration_seconds=duration,
            status="success",
        )
        logger.info(f"Done in {duration:.2f}s — {result}")
    except Exception as exc:
        duration = (datetime.now() - start).total_seconds()
        log_execution(
            script_name=Path(__file__).name,
            inputs={"input": args.input},
            outputs={},
            duration_seconds=duration,
            status="error",
            error=str(exc),
        )
        logger.error(f"Failed: {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()
