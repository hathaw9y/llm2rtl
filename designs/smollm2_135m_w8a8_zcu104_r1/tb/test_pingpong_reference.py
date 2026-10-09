"""Independent invariants for the control reference, not RTL signoff."""
import random
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from pingpong_reference import Slot, Tile, build_isa_program, make_tiles, simulate


class PingPongTests(unittest.TestCase):
    def check_trace(self, result):
        dma, gemm, ready = {}, {}, set()
        output = []
        last_cycle = -1
        for event in result["trace"]:
            cycle, bank, epoch, phase = (event[k] for k in
                                         ("cycle", "bank", "epoch", "phase"))
            self.assertGreaterEqual(cycle, last_cycle)
            last_cycle = cycle
            key = (bank, epoch, phase)
            if event["action"] == "accept":
                if phase == "gemm":
                    self.assertFalse(gemm)
                    self.assertIn((bank, epoch), ready)
                    self.assertNotIn(bank, [x[0] for x in dma])
                    ready.remove((bank, epoch))
                    gemm[key] = cycle
                else:
                    self.assertFalse(dma)
                    self.assertNotIn(bank, [x[0] for x in gemm])
                    dma[key] = cycle
            else:
                active = gemm if phase == "gemm" else dma
                self.assertIn(key, active)
                self.assertGreater(cycle, active.pop(key))
                if event["action"] == "complete":
                    if phase == "scale":
                        ready.add((bank, epoch))
                    if phase == "gemm":
                        output.append(epoch)
        self.assertFalse(dma)
        self.assertFalse(gemm)
        self.assertEqual(output, sorted(set(output)))

    def test_compute_and_dma_bottlenecks(self):
        for dma, gemm in [(5, 20), (20, 5), (5, 10)]:
            r = simulate(576, 576, dma, dma, gemm)
            self.check_trace(r)
            self.assertEqual(r["elapsed_cycles"], 2*dma + gemm + 2*max(2*dma, gemm))
            self.assertEqual(r["computed_tiles"], 3)
            self.assertEqual(r["slot_states"], {3: "FREE", 15: "FREE"})

    def test_overlap_and_reuse(self):
        r = simulate(1536, 1536, 3, 2, 17)
        self.check_trace(r)
        starts = {(e["epoch"], e["phase"]): e["cycle"]
                  for e in r["trace"] if e["action"] == "accept"}
        ends = {(e["epoch"], e["phase"]): e["cycle"]
                for e in r["trace"] if e["action"] == "complete"}
        self.assertLess(starts[1, "weight"], ends[0, "gemm"])
        self.assertGreaterEqual(starts[2, "weight"], ends[0, "gemm"])

    def test_single_and_partial_last_tile(self):
        for n in [1, 63, 64, 65, 191, 192, 193, 575, 576, 49152]:
            r = simulate(n, 576, 2, 1, 5, first_epoch=1000)
            self.check_trace(r)
            self.assertEqual(sum(t["n_count"] for t in r["tiles"]), n)
            self.assertEqual(r["computed_tiles"], (n+191)//192)
        self.assertEqual(make_tiles(193, 576)[-1].scale_bytes, 16)

    def test_random_timing(self):
        rng = random.Random(135)
        for _ in range(100):
            n = rng.randrange(1, 1537)
            count = (n+191)//192
            timings = [[rng.randrange(1, 40) for _ in range(count)] for _ in range(3)]
            r = simulate(n, 1536, *timings)
            self.check_trace(r)
            self.assertEqual(r["status"], "completed")

    def test_matched_errors_drain_and_stop_new_issue(self):
        for phase in ["weight", "scale", "gemm"]:
            r = simulate(1536, 576, 3, 2, 8, fault=(2, phase))
            self.check_trace(r)
            self.assertEqual(r["status"], "error_drained")
            first_error = next(e["cycle"] for e in r["trace"] if e["action"] == "error")
            self.assertFalse(any(e["action"] == "accept" and e["cycle"] >= first_error
                                 for e in r["trace"]))

    def test_guarded_transitions(self):
        slot = Slot(3)
        tile = Tile(10, 0, 192, 576)
        slot.begin(tile)
        with self.assertRaises(ValueError): slot.begin(tile)
        with self.assertRaises(ValueError): slot.activate()
        with self.assertRaises(ValueError): slot.finish_dma(9, "weight", tile.weight_bytes)
        with self.assertRaises(ValueError): slot.finish_dma(10, "weight", tile.weight_bytes-16)
        slot.finish_dma(10, "weight", tile.weight_bytes)
        with self.assertRaises(ValueError): slot.finish_dma(10, "weight", tile.weight_bytes)
        with self.assertRaises(ValueError): slot.activate()
        slot.finish_dma(10, "scale", tile.scale_bytes)
        slot.activate()
        with self.assertRaises(ValueError): slot.begin(Tile(11, 192, 192, 576))
        with self.assertRaises(ValueError): slot.finish_gemm(9)
        slot.finish_gemm(10)
        with self.assertRaises(ValueError): slot.finish_gemm(10)

    def test_invalid_requests(self):
        for n, k, width in [(0, 576, 192), (49153, 576, 192), (576, 0, 192),
                             (576, 577, 192), (576, 576, 16)]:
            with self.assertRaises(ValueError): simulate(n, k, 1, 1, 1, n_tile=width)
        with self.assertRaises(ValueError): simulate(576, 576, 0, 1, 1)
        with self.assertRaises(ValueError): simulate(576, 576, 1, 1, [1])

    def test_ps_isa_order_and_fragment_boundaries(self):
        program = build_isa_program(49152, 576)
        self.assertTrue(all(len(fragment) <= 16 and fragment[-1] == {"opcode": "END"}
                            for fragment in program))
        work = [r for fragment in program for r in fragment if r["opcode"] != "END"]
        self.assertEqual(len(work), 4*256)
        for index in range(256):
            config, data, scale, gemm = work[index*4:index*4+4]
            self.assertEqual([r["opcode"] for r in [config, data, scale, gemm]],
                             ["BANK_CONFIG", "DMA_LOAD", "DMA_LOAD", "GEMM_INT8"])
            self.assertTrue(all(r["bank"] == (3, 15)[index % 2]
                                for r in [config, data, scale, gemm]))
            self.assertEqual(data["DDR_byte_offset"], index*192*576)
            self.assertEqual(scale["DDR_byte_offset"], index*48)
            self.assertEqual(scale["bank_byte_offset"], 294912)
            self.assertFalse(any("DDR" in key for key in gemm))
        with self.assertRaises(ValueError): build_isa_program(576, 576, fragment_records=16)

    def test_END_drains_preserve_prefetch_and_partial_fill(self):
        baseline = simulate(1536, 576, 3, 2, 17)
        for limit in [1, 2, 3, 7, 15]:
            result = simulate(1536, 576, 3, 2, 17, fragment_records=limit)
            self.check_trace(result)
            self.assertEqual(result["computed_tiles"], 8)
            self.assertEqual(len(result["fragment_events"]), (32+limit-1)//limit)
            self.assertGreaterEqual(result["elapsed_cycles"], baseline["elapsed_cycles"])
            self.assertFalse(any("ACTIVE" in x["bank_states"].values()
                                 for x in result["fragment_events"]))
        result = simulate(1536, 576, 3, 2, 17, fragment_records=3)
        self.assertTrue(any("READY" in x["bank_states"].values()
                            for x in result["fragment_events"]))
        result = simulate(1536, 576, 3, 2, 17, fragment_records=1)
        self.assertTrue(any("FILLING" in x["bank_states"].values()
                            for x in result["fragment_events"]))


if __name__ == "__main__":
    unittest.main()
