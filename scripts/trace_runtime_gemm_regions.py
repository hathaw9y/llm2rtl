#!/usr/bin/env python3
"""Run a model factory and write a non-overwriting GEMM/NON_GEMM trace."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from frontend.runtime_gemm_trace import trace_model_execution  # noqa: E402


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_factory(specification: str):
    if ":" not in specification:
        raise ValueError("factory must be ABSOLUTE_OR_RELATIVE_PATH.py:function")
    source_text, function_name = specification.rsplit(":", 1)
    source = Path(source_text).expanduser().resolve()
    if not source.is_file():
        raise FileNotFoundError(f"factory source does not exist: {source}")
    module_spec = importlib.util.spec_from_file_location("llm2rtl_trace_factory", source)
    if module_spec is None or module_spec.loader is None:
        raise RuntimeError(f"cannot import factory source: {source}")
    module = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(module)
    factory = getattr(module, function_name, None)
    if not callable(factory):
        raise TypeError(f"factory is not callable: {function_name}")
    return source, factory


def validate_case(case: Any) -> dict[str, Any]:
    if not isinstance(case, dict):
        raise TypeError("factory must return a dict")
    if "model" not in case:
        raise ValueError("factory result is missing model")
    args = case.get("args", ())
    kwargs = case.get("kwargs", {})
    metadata = case.get("metadata", {})
    if not isinstance(args, tuple):
        raise TypeError("factory args must be a tuple")
    if not isinstance(kwargs, dict) or not isinstance(metadata, dict):
        raise TypeError("factory kwargs and metadata must be dicts")
    return {"model": case["model"], "args": args, "kwargs": kwargs,
            "metadata": metadata}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--factory", required=True,
                        help="PATH.py:function returning model/args/kwargs/metadata")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--include-raw-events", action="store_true")
    parser.add_argument("--gemm-op", action="append", default=[],
                        help="additional dispatcher operator base name")
    arguments = parser.parse_args()

    output = arguments.output.expanduser().resolve()
    if output.exists():
        raise FileExistsError(f"refusing to overwrite existing trace: {output}")

    source, factory = load_factory(arguments.factory)
    case = validate_case(factory())
    metadata = dict(case["metadata"])
    metadata.update(
        {
            "factory_source": str(source),
            "factory_source_sha256": sha256(source),
        }
    )
    _, report = trace_model_execution(
        case["model"],
        case["args"],
        case["kwargs"],
        metadata=metadata,
        additional_matrix_ops=arguments.gemm_op,
        include_raw_events=arguments.include_raw_events,
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("x", encoding="utf-8") as stream:
        json.dump(report, stream, indent=2)
        stream.write("\n")
    print(json.dumps({
        "status": "PASS_RUNTIME_GEMM_TRACE",
        "output": str(output),
        "raw_event_count": report["raw_event_count"],
        "region_count": report["region_count"],
        "gemm_event_count": report["gemm_event_count"],
        "non_gemm_event_count": report["non_gemm_event_count"],
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
