#!/usr/bin/env python3
"""Compile a declarative kernel variant into pre-RTL derived contracts."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _signed_range(bits: int) -> tuple[int, int]:
    return (-(1 << (bits - 1)), (1 << (bits - 1)) - 1)


def _canonical_hash(spec: dict[str, Any]) -> str:
    encoded = json.dumps(spec, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def _base_checks(spec: dict[str, Any], errors: list[str]) -> dict[str, dict[str, Any]]:
    required = (
        "schema", "variant_id", "operation", "architecture", "tile",
        "numeric", "tensor_ports", "accumulation", "scheduler", "target",
    )
    for key in required:
        if key not in spec:
            errors.append(f"missing required field: {key}")

    if spec.get("schema") != "llm2rtl_v2.kernel_variant.v1":
        errors.append("schema must be llm2rtl_v2.kernel_variant.v1")

    ports_by_role: dict[str, dict[str, Any]] = {}
    ports = spec.get("tensor_ports", [])
    if not isinstance(ports, list) or not ports:
        errors.append("tensor_ports must be a non-empty array")
        return ports_by_role

    for index, port in enumerate(ports):
        if not isinstance(port, dict):
            errors.append(f"tensor_ports[{index}] must be an object")
            continue
        role = port.get("role")
        if not isinstance(role, str) or not role:
            errors.append(f"tensor_ports[{index}].role must be a non-empty string")
            continue
        if role in ports_by_role:
            errors.append(f"duplicate tensor port role: {role}")
        ports_by_role[role] = port
        if port.get("direction") not in ("read", "write"):
            errors.append(f"{role}: direction must be read or write")
        for field in ("element_bits", "port_bits", "memory_native_port_bits"):
            if not _positive_int(port.get(field)):
                errors.append(f"{role}: {field} must be a positive integer")
        port_bits = port.get("port_bits")
        native_bits = port.get("memory_native_port_bits")
        element_bits = port.get("element_bits")
        if _positive_int(port_bits) and _positive_int(native_bits) and port_bits != native_bits:
            errors.append(
                f"{role}: logical port width {port_bits} does not equal native memory width {native_bits}"
            )
        if _positive_int(port_bits) and _positive_int(element_bits) and port_bits % element_bits:
            errors.append(f"{role}: port width is not divisible by element width")
        if not port.get("packing"):
            errors.append(f"{role}: packing policy is required")
        if port.get("memory_class") == "external_ps_ddr":
            errors.append(
                f"{role}: tensor port memory_class must not be external_ps_ddr; "
                "a compute engine's own ports terminate at local memory "
                "(ip_internal_private, vendor_child_private, system_shared_pl, or "
                "system_weight_uram) and DDR movement belongs to a separate "
                "infrastructure IP's external_transfers, not a direct compute "
                "tensor_port"
            )
    return ports_by_role


def _compile_gemm(
    spec: dict[str, Any], ports: dict[str, dict[str, Any]], errors: list[str]
) -> dict[str, Any]:
    tile = spec.get("tile", {})
    numeric = spec.get("numeric", {})
    for axis in ("m", "n", "k"):
        if not _positive_int(tile.get(axis)):
            errors.append(f"gemm tile.{axis} must be a positive integer")

    required_numeric = (
        "activation_bits", "weight_bits", "product_bits", "accumulator_bits",
        "activation_signed", "weight_signed", "accumulator_signed",
    )
    for field in required_numeric:
        if field not in numeric:
            errors.append(f"gemm numeric.{field} is required")
    for field in ("activation_bits", "weight_bits", "product_bits", "accumulator_bits"):
        if field in numeric and not _positive_int(numeric[field]):
            errors.append(f"gemm numeric.{field} must be a positive integer")

    for role in ("activation", "weight", "output"):
        if role not in ports:
            errors.append(f"gemm requires tensor port role: {role}")

    m = tile.get("m", 0)
    n = tile.get("n", 0)
    k = tile.get("k", 0)
    a_bits = numeric.get("activation_bits", 0)
    w_bits = numeric.get("weight_bits", 0)
    p_bits = numeric.get("product_bits", 0)
    acc_bits = numeric.get("accumulator_bits", 0)

    expected_widths = {
        "activation": k * a_bits,
        "weight": n * w_bits,
        "partial_sum": n * acc_bits,
        "output": n * acc_bits,
    }
    for role, expected in expected_widths.items():
        if role in ports and expected and ports[role].get("port_bits") != expected:
            errors.append(
                f"gemm {role}: one-row packing requires {expected} bits, got {ports[role].get('port_bits')}"
            )

    if a_bits and w_bits and p_bits < a_bits + w_bits:
        errors.append("gemm product_bits must be at least activation_bits + weight_bits")

    accumulation = spec.get("accumulation", {})
    across_k = accumulation.get("across_k_tiles") is True
    if across_k:
        if "partial_sum" not in ports or ports.get("partial_sum", {}).get("direction") != "read":
            errors.append("cross-K accumulation requires a partial_sum read port")
        if ports.get("output", {}).get("direction") != "write":
            errors.append("cross-K accumulation requires an output write port")
        for field in ("storage", "first_k_tile", "later_k_tiles", "overflow"):
            if not accumulation.get(field):
                errors.append(f"cross-K accumulation requires accumulation.{field}")

    scheduler = spec.get("scheduler", {})
    for field in ("full_dimensions_owned_by", "loop_order", "edge_policy", "global_stride_owned_by"):
        if not scheduler.get(field):
            errors.append(f"gemm scheduler.{field} is required")
    if scheduler.get("loop_order") != ["m", "n", "k"]:
        errors.append("current GEMM scheduler contract requires loop_order [m, n, k]")
    if scheduler.get("full_dimensions_owned_by") != "gemm_engine":
        errors.append("runtime-variable GEMM requires full dimensions to be owned by gemm_engine")
    if scheduler.get("global_stride_owned_by") != "gemm_engine":
        errors.append("runtime-variable GEMM requires packed tile address generation in gemm_engine")

    external_output = spec.get("external_transfers", {}).get("output")
    expected_output_tile_bytes = m * n * acc_bits // 8 if all(
        _positive_int(value) for value in (m, n, acc_bits)
    ) and (m * n * acc_bits) % 8 == 0 else None
    if scheduler.get("local_output_policy") == "reuse_one_tile_buffer_after_ddr_drain":
        if not isinstance(external_output, dict):
            errors.append("reusable local output tile buffer requires external_transfers.output")
        else:
            if external_output.get("direction") != "local_to_ddr":
                errors.append("GEMM output transfer direction must be local_to_ddr")
            if external_output.get("when") != "after_final_k_tile_per_output_tile":
                errors.append("reusable output buffer must drain after each final K tile")
            if external_output.get("bytes_per_tile") != expected_output_tile_bytes:
                errors.append(
                    "output DDR bytes_per_tile must equal the complete packed output tile size "
                    f"{expected_output_tile_bytes}"
                )
            for field in (
                "transport", "ddr_region_start_hex", "ddr_region_end_inclusive_hex",
                "alignment_bytes",
            ):
                if not external_output.get(field):
                    errors.append(f"external output transfer requires {field}")

    single_tile_bound = None
    accumulator_fits_single_tile = None
    if all(_positive_int(value) for value in (k, a_bits, w_bits, acc_bits)):
        a_min, a_max = _signed_range(a_bits)
        w_min, w_max = _signed_range(w_bits)
        products = (a_min * w_min, a_min * w_max, a_max * w_min, a_max * w_max)
        max_abs_product = max(abs(value) for value in products)
        single_tile_bound = k * max_abs_product
        acc_min, acc_max = _signed_range(acc_bits)
        accumulator_fits_single_tile = single_tile_bound <= min(abs(acc_min), acc_max)
        if not accumulator_fits_single_tile and not accumulation.get("overflow"):
            errors.append("single-tile accumulator may overflow but overflow policy is missing")

    architecture = spec.get("architecture", {})
    pe_rows = architecture.get("physical_pe_rows")
    pe_columns = architecture.get("physical_pe_columns")
    if pe_rows != k or pe_columns != n:
        errors.append("weight-stationary physical PE rows/columns must equal tile k/n")

    router_instances = []
    for role in ("activation", "weight", "partial_sum", "output"):
        if role in ports:
            port = ports[role]
            router_instances.append({
                "role": role,
                "module": "data_read_router" if port.get("direction") == "read" else "data_write_router",
                "data_width": port.get("port_bits"),
                "write_enable_width": port.get("port_bits", 0) // 8 if port.get("direction") == "write" else None,
            })

    return {
        "tile": {"m": m, "n": n, "k": k},
        "physical_pe_count": pe_rows * pe_columns if _positive_int(pe_rows) and _positive_int(pe_columns) else None,
        "true_parallel_product_paths": pe_rows * pe_columns if _positive_int(pe_rows) and _positive_int(pe_columns) else None,
        "natural_row_width_bits": expected_widths,
        "native_words_per_tile": {"activation": m, "weight": k, "partial_sum": m, "output": m},
        "private_result_bits": m * n * acc_bits if all(_positive_int(value) for value in (m, n, acc_bits)) else None,
        "single_k_tile_max_abs_sum_bound": single_tile_bound,
        "accumulator_fits_single_k_tile": accumulator_fits_single_tile,
        "cross_k_accumulation": across_k,
        "router_count": len(router_instances),
        "router_instances": router_instances,
        "scheduler_loop_order": scheduler.get("loop_order"),
        "full_dimensions_owned_by": scheduler.get("full_dimensions_owned_by"),
        "edge_policy": scheduler.get("edge_policy"),
        "local_output_policy": scheduler.get("local_output_policy"),
        "output_ddr_bytes_per_tile": expected_output_tile_bytes,
        "output_external_transfer": external_output,
        "address_formulas_native_words": {
            "activation": "A0 + (m_tile*k_tiles+k_tile)*tile_m",
            "weight": "W0 + (k_tile*n_tiles+n_tile)*tile_k",
            "output_partial_sum": "C0 reusable local tile buffer",
        },
    }


def compile_variant(
    spec: dict[str, Any],
    model_config: dict[str, Any] | None = None,
    hardware_config: dict[str, Any] | None = None,
) -> dict[str, Any]:
    errors: list[str] = []
    ports = _base_checks(spec, errors)
    operation = spec.get("operation")
    if operation == "gemm":
        derived = _compile_gemm(spec, ports, errors)
    else:
        errors.append(
            f"no operation validator registered for {operation!r}; add a plugin before RTL generation"
        )
        derived = {}
    compatibility: dict[str, Any] = {}
    if model_config is not None:
        model_quant = model_config.get("quantization", {})
        numeric = spec.get("numeric", {})
        model_checks = {
            "weight_bits": (model_quant.get("weight_bits"), numeric.get("weight_bits")),
            "activation_bits": (
                model_quant.get("activation_bits"), numeric.get("activation_bits")
            ),
        }
        mismatches = []
        for field, (model_value, variant_value) in model_checks.items():
            if model_value != variant_value:
                mismatches.append({
                    "field": field,
                    "model": model_value,
                    "variant": variant_value,
                })
                errors.append(
                    f"model/variant mismatch for {field}: model={model_value}, variant={variant_value}"
                )
        compatibility["model"] = {
            "name": model_config.get("model_name"),
            "compatible": not mismatches,
            "mismatches": mismatches,
        }
    if hardware_config is not None:
        target = spec.get("target", {})
        mismatches = []
        for field in ("board", "part"):
            if hardware_config.get(field) != target.get(field):
                mismatches.append({
                    "field": field,
                    "hardware": hardware_config.get(field),
                    "variant": target.get(field),
                })
        if hardware_config.get("target_clock_mhz") != target.get("clock_mhz"):
            mismatches.append({
                "field": "clock_mhz",
                "hardware": hardware_config.get("target_clock_mhz"),
                "variant": target.get("clock_mhz"),
            })
        for mismatch in mismatches:
            errors.append(
                "hardware/variant mismatch for "
                f"{mismatch['field']}: hardware={mismatch['hardware']}, variant={mismatch['variant']}"
            )
        pe_count = derived.get("physical_pe_count") or 0
        dsp_per_pe = spec.get("architecture", {}).get("dsp_per_pe_intent", 0)
        estimated_dsp = pe_count * dsp_per_pe if _positive_int(pe_count) else 0
        available_dsp = hardware_config.get("device_inventory", {}).get("dsp")
        if isinstance(available_dsp, int) and estimated_dsp > available_dsp:
            errors.append(
                f"estimated DSP demand {estimated_dsp} exceeds device inventory {available_dsp}"
            )
        compatibility["hardware"] = {
            "compatible": not mismatches and not (
                isinstance(available_dsp, int) and estimated_dsp > available_dsp
            ),
            "mismatches": mismatches,
            "estimated_dsp": estimated_dsp,
            "available_dsp": available_dsp,
        }
    return {
        "schema": "llm2rtl_v2.derived_kernel_contract.v1",
        "variant_id": spec.get("variant_id"),
        "variant_hash_sha256": _canonical_hash(spec),
        "operation": operation,
        "valid": not errors,
        "errors": errors,
        "compatibility": compatibility,
        "derived": derived,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("spec", type=Path, nargs="?")
    parser.add_argument("--contract-index")
    parser.add_argument("--expected-sha256")
    parser.add_argument("--module")
    parser.add_argument("--fixture-only", action="store_true",
                        help="Explicit standalone regression mode; not a design contract gate")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--model-config", type=Path)
    parser.add_argument("--hardware-config", type=Path)
    args = parser.parse_args()
    if args.output:
        root = Path(__file__).resolve().parents[2]
        if args.output.exists() or args.output.is_symlink():
            parser.error("output must be a fresh file; overwriting inputs or evidence is forbidden")
        if args.output.resolve().is_relative_to(root / "contracts"):
            parser.error("derived output must not be written into contracts")
    bundle = None
    if args.fixture_only:
        if not args.spec or any((args.contract_index, args.expected_sha256, args.module)):
            parser.error("fixture-only needs a spec and cannot consume a design index")
        spec = json.loads(args.spec.read_text())
        model_config = json.loads(args.model_config.read_text()) if args.model_config else None
        hardware_config = json.loads(args.hardware_config.read_text()) if args.hardware_config else None
    else:
        if not all((args.contract_index, args.expected_sha256, args.module)):
            parser.error("design mode requires --contract-index, --expected-sha256 and --module")
        if any((args.spec, args.model_config, args.hardware_config)):
            parser.error("design mode consumes only the frozen bundle; overrides are forbidden")
        root = Path(__file__).resolve().parents[2]
        sys.path.insert(0, str(root / "scripts"))
        from design_contracts import consume, ContractError
        try:
            bundle = consume(root, args.contract_index, args.expected_sha256, args.module)
            spec = bundle["module"].get("variant")
            if not isinstance(spec, dict):
                raise ContractError("selected module needs an inline variant object")
            model_config = bundle["module"].get("model_config")
            hardware_config = bundle["hardware_profile"]
        except (ContractError, OSError, ValueError) as error:
            print(json.dumps({"valid": False, "errors": [str(error)]}))
            return 1
    report = compile_variant(spec, model_config, hardware_config)
    if bundle:
        try:
            consume(root, args.contract_index, args.expected_sha256, args.module)
        except (ContractError, OSError, ValueError) as error:
            print(json.dumps({"valid": False, "errors": [str(error)]}))
            return 1
    report["contract_gate"] = ({"status": "passed", "index": args.contract_index,
                               "index_sha256": args.expected_sha256, "module": args.module}
                              if bundle else {"status": "not_run", "scope": "fixture_only"})
    encoded = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open('x') as output_file:
            output_file.write(encoded)
    print(encoded, end="")
    return 0 if report["valid"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
