"""Runtime GEMM/NON_GEMM tracing without exporting or rewriting a model.

The tracer observes PyTorch dispatcher operations from one concrete execution.
It deliberately performs only a mathematical classification.  Whether a GEMM
event is supported by a particular FPGA executor remains unresolved until a
separate capability check is performed.
"""

from __future__ import annotations

from collections import Counter
from contextlib import contextmanager
from dataclasses import dataclass, field
from typing import Any, Iterable, Mapping, Sequence

import torch
from torch.utils._python_dispatch import TorchDispatchMode


DEFAULT_MATRIX_OPS = frozenset(
    {
        "addmm",
        "addmv",
        "baddbmm",
        "bmm",
        "linear",
        "matmul",
        "mm",
        "mv",
        "_scaled_mm",
    }
)


def _operator_base_name(func: Any) -> str:
    text = str(func)
    parts = text.split(".")
    if len(parts) >= 2 and parts[0] == "aten":
        return parts[1]
    return text


def _tensor_descriptor(value: torch.Tensor) -> dict[str, Any]:
    return {
        "shape": [str(dim) if not isinstance(dim, int) else dim for dim in value.shape],
        "dtype": str(value.dtype).removeprefix("torch."),
        "device": str(value.device),
        "requires_grad": bool(value.requires_grad),
    }


def _flatten_tensors(value: Any, path: str = "") -> list[tuple[str, torch.Tensor]]:
    if isinstance(value, torch.Tensor):
        return [(path or "$", value)]
    if isinstance(value, Mapping):
        flattened: list[tuple[str, torch.Tensor]] = []
        for key, item in value.items():
            flattened.extend(_flatten_tensors(item, f"{path}.{key}" if path else str(key)))
        return flattened
    if isinstance(value, (tuple, list)):
        flattened = []
        for index, item in enumerate(value):
            flattened.extend(_flatten_tensors(item, f"{path}[{index}]"))
        return flattened
    return []


def _describe_tensors(value: Any) -> list[dict[str, Any]]:
    return [dict(path=path, **_tensor_descriptor(tensor))
            for path, tensor in _flatten_tensors(value)]


def _storage_key(tensor: torch.Tensor) -> tuple[Any, ...] | None:
    if tensor.device.type == "meta":
        return None
    try:
        storage = tensor.untyped_storage()
        return (storage.data_ptr(), storage.nbytes(), str(tensor.device))
    except (RuntimeError, NotImplementedError):
        return None


@dataclass
class _ModuleStack:
    stack: list[str] = field(default_factory=list)
    handles: list[Any] = field(default_factory=list)

    def install(self, model: torch.nn.Module) -> None:
        for name, module in model.named_modules(remove_duplicate=False):
            display_name = name or "<root>"

            def pre_hook(_module: torch.nn.Module, _args: tuple[Any, ...],
                         module_name: str = display_name) -> None:
                self.stack.append(module_name)

            def post_hook(_module: torch.nn.Module, _args: tuple[Any, ...], _output: Any,
                          module_name: str = display_name) -> None:
                if not self.stack:
                    raise RuntimeError(f"module stack underflow at {module_name}")
                popped = self.stack.pop()
                if popped != module_name:
                    raise RuntimeError(
                        f"module stack mismatch: expected {module_name}, observed {popped}"
                    )

            self.handles.append(module.register_forward_pre_hook(pre_hook))
            try:
                handle = module.register_forward_hook(post_hook, always_call=True)
            except TypeError:
                handle = module.register_forward_hook(post_hook)
            self.handles.append(handle)

    def remove(self) -> None:
        for handle in reversed(self.handles):
            handle.remove()
        self.handles.clear()
        self.stack.clear()


class RuntimeGemmTracer(TorchDispatchMode):
    """Observe one execution and classify matrix versus non-matrix operators."""

    def __init__(
        self,
        model: torch.nn.Module,
        *,
        additional_matrix_ops: Iterable[str] = (),
        include_raw_events: bool = False,
    ) -> None:
        super().__init__()
        self.model = model
        self.matrix_ops = DEFAULT_MATRIX_OPS | frozenset(additional_matrix_ops)
        self.include_raw_events = include_raw_events
        self.events: list[dict[str, Any]] = []
        self.module_stack = _ModuleStack()
        self.parameter_storage: dict[tuple[Any, ...], list[str]] = {}
        for name, parameter in model.named_parameters(remove_duplicate=False):
            key = _storage_key(parameter)
            if key is not None:
                self.parameter_storage.setdefault(key, []).append(name)

    @contextmanager
    def installed(self):
        self.module_stack.install(self.model)
        try:
            with self:
                yield self
        finally:
            self.module_stack.remove()

    def __torch_dispatch__(
        self,
        func: Any,
        types: Sequence[type],
        args: tuple[Any, ...] = (),
        kwargs: Mapping[str, Any] | None = None,
    ) -> Any:
        del types
        actual_kwargs = dict(kwargs or {})
        output = func(*args, **actual_kwargs)
        base_name = _operator_base_name(func)
        input_tensors = _flatten_tensors((args, actual_kwargs))
        parameter_names: list[str] = []
        for _, tensor in input_tensors:
            key = _storage_key(tensor)
            if key is not None:
                parameter_names.extend(self.parameter_storage.get(key, ()))
        parameter_names = sorted(set(parameter_names))
        is_matrix = base_name in self.matrix_ops
        if is_matrix and parameter_names:
            variant = "WEIGHT_GEMM"
        elif is_matrix:
            variant = "DYNAMIC_GEMM"
        else:
            variant = None
        self.events.append(
            {
                "event_index": len(self.events),
                "kind": "GEMM" if is_matrix else "NON_GEMM",
                "variant": variant,
                "operator": str(func),
                "operator_base": base_name,
                "module_stack": list(self.module_stack.stack),
                "parameter_names": parameter_names,
                "inputs": _describe_tensors((args, actual_kwargs)),
                "outputs": _describe_tensors(output),
            }
        )
        return output

    def build_report(self, metadata: Mapping[str, Any] | None = None) -> dict[str, Any]:
        regions: list[dict[str, Any]] = []
        pending: list[dict[str, Any]] = []

        def flush_non_gemm() -> None:
            if not pending:
                return
            counts = Counter(event["operator"] for event in pending)
            module_paths: list[str] = []
            seen: set[str] = set()
            for event in pending:
                for path in event["module_stack"]:
                    if path not in seen:
                        module_paths.append(path)
                        seen.add(path)
            regions.append(
                {
                    "region_index": len(regions),
                    "kind": "NON_GEMM",
                    "first_event_index": pending[0]["event_index"],
                    "last_event_index": pending[-1]["event_index"],
                    "operator_count": len(pending),
                    "operator_histogram": dict(counts),
                    "module_paths": module_paths,
                    "first_operator_inputs": pending[0]["inputs"],
                    "last_operator_outputs": pending[-1]["outputs"],
                    "mapping_status": "UNRESOLVED",
                }
            )
            pending.clear()

        for event in self.events:
            if event["kind"] == "NON_GEMM":
                pending.append(event)
                continue
            flush_non_gemm()
            region = dict(event)
            region["region_index"] = len(regions)
            region["hardware_mapping"] = "UNRESOLVED"
            regions.append(region)
        flush_non_gemm()

        report: dict[str, Any] = {
            "schema": "llm2rtl.runtime_gemm_trace.v1",
            "scope": "one_observed_execution_path",
            "classification_policy": {
                "matrix_operator_bases": sorted(self.matrix_ops),
                "gemm_is_mathematical_not_hardware_compatibility": True,
                "non_gemm_regions_are_uninterpreted": True,
            },
            "metadata": dict(metadata or {}),
            "raw_event_count": len(self.events),
            "region_count": len(regions),
            "gemm_event_count": sum(event["kind"] == "GEMM" for event in self.events),
            "non_gemm_event_count": sum(event["kind"] == "NON_GEMM" for event in self.events),
            "regions": regions,
        }
        if self.include_raw_events:
            report["raw_events"] = self.events
        return report


def trace_model_execution(
    model: torch.nn.Module,
    args: tuple[Any, ...] = (),
    kwargs: Mapping[str, Any] | None = None,
    *,
    metadata: Mapping[str, Any] | None = None,
    additional_matrix_ops: Iterable[str] = (),
    include_raw_events: bool = False,
) -> tuple[Any, dict[str, Any]]:
    """Run one inference path and return its result plus a trace report."""

    tracer = RuntimeGemmTracer(
        model,
        additional_matrix_ops=additional_matrix_ops,
        include_raw_events=include_raw_events,
    )
    with torch.inference_mode(), tracer.installed():
        result = model(*args, **dict(kwargs or {}))
    return result, tracer.build_report(metadata)
