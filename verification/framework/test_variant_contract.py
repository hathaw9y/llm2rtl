#!/usr/bin/env python3

import copy
import importlib.util
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "src" / "codegen" / "variant_contract.py"
SPEC_PATH = Path(__file__).resolve().parent / "fixtures" / "projection_gemm_ws32_w4a4_acc16.json"
LOADER_SPEC = importlib.util.spec_from_file_location("variant_contract", MODULE_PATH)
assert LOADER_SPEC and LOADER_SPEC.loader
VARIANT_CONTRACT = importlib.util.module_from_spec(LOADER_SPEC)
LOADER_SPEC.loader.exec_module(VARIANT_CONTRACT)


class VariantContractTest(unittest.TestCase):
    def setUp(self):
        self.spec = json.loads(SPEC_PATH.read_text())

    def test_current_gemm_derives_four_native_routers(self):
        report = VARIANT_CONTRACT.compile_variant(self.spec)
        self.assertTrue(report["valid"], report["errors"])
        self.assertEqual(report["derived"]["physical_pe_count"], 1024)
        self.assertEqual(report["derived"]["router_count"], 4)
        self.assertEqual(report["derived"]["natural_row_width_bits"]["output"], 512)
        self.assertEqual(report["derived"]["native_words_per_tile"]["output"], 32)
        self.assertEqual(report["derived"]["output_ddr_bytes_per_tile"], 2048)
        self.assertEqual(report["derived"]["full_dimensions_owned_by"], "gemm_engine")
        self.assertTrue(report["derived"]["cross_k_accumulation"])

    def test_rejects_native_width_mismatch(self):
        broken = copy.deepcopy(self.spec)
        broken["tensor_ports"][3]["memory_native_port_bits"] = 128
        report = VARIANT_CONTRACT.compile_variant(broken)
        self.assertFalse(report["valid"])
        self.assertTrue(any("does not equal native memory width" in error for error in report["errors"]))

    def test_rejects_missing_partial_sum_read(self):
        broken = copy.deepcopy(self.spec)
        broken["tensor_ports"] = [
            port for port in broken["tensor_ports"] if port["role"] != "partial_sum"
        ]
        report = VARIANT_CONTRACT.compile_variant(broken)
        self.assertFalse(report["valid"])
        self.assertTrue(any("partial_sum read port" in error for error in report["errors"]))

    def test_rejects_wrong_output_word_width(self):
        broken = copy.deepcopy(self.spec)
        output = next(port for port in broken["tensor_ports"] if port["role"] == "output")
        output["port_bits"] = 128
        output["memory_native_port_bits"] = 128
        report = VARIANT_CONTRACT.compile_variant(broken)
        self.assertFalse(report["valid"])
        self.assertTrue(any("one-row packing requires 512 bits" in error for error in report["errors"]))

    def test_rejects_model_bitwidth_mismatch(self):
        model = {"quantization": {"weight_bits": 2, "activation_bits": 2}}
        report = VARIANT_CONTRACT.compile_variant(self.spec, model_config=model)
        self.assertFalse(report["valid"])
        self.assertEqual(len(report["compatibility"]["model"]["mismatches"]), 2)

    def test_rejects_output_drain_size_mismatch(self):
        broken = copy.deepcopy(self.spec)
        broken["external_transfers"]["output"]["bytes_per_tile"] = 512
        report = VARIANT_CONTRACT.compile_variant(broken)
        self.assertFalse(report["valid"])
        self.assertTrue(any("bytes_per_tile" in error for error in report["errors"]))

    def test_rejects_compute_tensor_port_owning_external_ddr(self):
        broken = copy.deepcopy(self.spec)
        broken["tensor_ports"][0]["memory_class"] = "external_ps_ddr"
        report = VARIANT_CONTRACT.compile_variant(broken)
        self.assertFalse(report["valid"])
        self.assertTrue(any("must not be external_ps_ddr" in error for error in report["errors"]))


if __name__ == "__main__":
    unittest.main()
