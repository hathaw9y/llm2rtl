#!/usr/bin/env python3
import unittest
from capacity_overlap import calculate, packed

def cfg(cap=4096,bw=10000,lat=.001,comp=.02,base=.2,tile=100):
    return {"onchip_capacity_bytes":cap,"reserve_bytes":0,"sustained_bandwidth_bytes_per_s":bw,"transfer_latency_s":lat,"compute_tile_s":comp,"prefetch_distance":2,"tiles":4,"measured_resident_latency_s":base,"datasets":[{"name":"weights","mode":"streamed","total_elements":10000,"tile_elements":tile,"bits":4,"alignment_bytes":16},{"name":"scales","mode":"resident","total_elements":32,"bits":16,"alignment_bytes":16}]}

class Test(unittest.TestCase):
    def test_subbyte_alignment(self): self.assertEqual(packed(33,4,16),32)
    def test_pingpong(self): self.assertEqual(calculate(cfg())["decision"],"pingpong")
    def test_resident(self):
        c=cfg(cap=20000,base=.01); self.assertEqual(calculate(c)["decision"],"resident")
    def test_reduced_when_two_banks_do_not_fit(self):
        c=cfg(cap=128,tile=100); self.assertEqual(calculate(c)["decision"],"reduced")
    def test_measure_without_baseline(self):
        c=cfg(); del c["measured_resident_latency_s"]; self.assertEqual(calculate(c)["decision"],"measure")
    def test_bandwidth_failure(self):
        c=cfg(bw=10); self.assertFalse(calculate(c)["steady_state_overlap_pass"])
    def test_serial_latency_is_part_of_steady_service(self):
        c=cfg(bw=6400,lat=.015,comp=.020,base=1.0,tile=100); r=calculate(c)
        self.assertAlmostEqual(r["payload_transfer_s"],.010)
        self.assertAlmostEqual(r["steady_state_service_s"],.025)
        self.assertFalse(r["steady_state_overlap_pass"])
        self.assertTrue(r["prefetch_overlap_pass"])
        self.assertNotEqual(r["decision"],"pingpong")
    def test_serial_pipeline_prediction_uses_service(self):
        c=cfg(bw=6400,lat=.015,comp=.020,base=1.0,tile=100); r=calculate(c)
        self.assertAlmostEqual(r["pipeline_cycle_s"],.025)
        self.assertAlmostEqual(r["predicted_pingpong_latency_s"],.120)
    def test_proven_multi_outstanding_can_overlap_fixed_latency(self):
        c=cfg(bw=6400,lat=.015,comp=.020,base=1.0,tile=100)
        c["fixed_latency_overlap_proven"]=True; c["latency_overlap_evidence"]="measured four-outstanding tagged mover"
        r=calculate(c); self.assertTrue(r["steady_state_overlap_pass"]); self.assertEqual(r["decision"],"pingpong")
    def test_overlap_claim_requires_evidence(self):
        c=cfg(); c["fixed_latency_overlap_proven"]=True
        with self.assertRaises(ValueError): calculate(c)
    def test_bad_mode(self):
        c=cfg(); c["datasets"][0]["mode"]="magic"
        with self.assertRaises(ValueError): calculate(c)
if __name__=="__main__": unittest.main()
