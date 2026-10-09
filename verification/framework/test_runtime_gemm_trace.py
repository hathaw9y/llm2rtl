import sys
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src"))

try:
    import torch
    from frontend.runtime_gemm_trace import trace_model_execution
except ImportError:
    torch = None
    trace_model_execution = None


@unittest.skipIf(torch is None, "PyTorch is not installed in this test environment")
class RuntimeGemmTraceTest(unittest.TestCase):
    def test_weight_dynamic_and_non_gemm_regions(self):
        class Fixture(torch.nn.Module):
            def __init__(self):
                super().__init__()
                self.projection = torch.nn.Linear(4, 4, bias=False)

            def forward(self, value, dynamic_weight):
                projected = self.projection(value)
                activated = torch.relu(projected)
                return torch.matmul(activated, dynamic_weight)

        model = Fixture().eval()
        value = torch.ones(2, 4)
        dynamic_weight = torch.eye(4)
        output, report = trace_model_execution(
            model,
            (value, dynamic_weight),
            metadata={"fixture": True},
            include_raw_events=True,
        )
        self.assertEqual(tuple(output.shape), (2, 4))
        self.assertEqual(report["schema"], "llm2rtl.runtime_gemm_trace.v1")
        gemms = [region for region in report["regions"] if region["kind"] == "GEMM"]
        self.assertGreaterEqual(len(gemms), 2)
        self.assertEqual(gemms[0]["variant"], "WEIGHT_GEMM")
        self.assertEqual(gemms[-1]["variant"], "DYNAMIC_GEMM")
        self.assertIn("projection.weight", gemms[0]["parameter_names"])
        non_gemms = [region for region in report["regions"]
                     if region["kind"] == "NON_GEMM"]
        self.assertTrue(any("aten.relu.default" in region["operator_histogram"]
                            for region in non_gemms))

    def test_report_does_not_claim_hardware_compatibility(self):
        model = torch.nn.Linear(3, 2, bias=False).eval()
        _, report = trace_model_execution(model, (torch.ones(1, 3),))
        gemm = next(region for region in report["regions"] if region["kind"] == "GEMM")
        self.assertEqual(gemm["hardware_mapping"], "UNRESOLVED")
        self.assertTrue(report["classification_policy"]
                        ["gemm_is_mathematical_not_hardware_compatibility"])


if __name__ == "__main__":
    unittest.main()
