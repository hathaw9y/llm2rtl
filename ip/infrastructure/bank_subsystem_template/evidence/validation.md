# Native bank template validation

DMA-only template and separate ownership/routing/memory children implemented. Fixed roles are MM2S/S2MM only. Design Agents generate compute-specific ports and configuration. Existing legacy bank_subsystem and execution_fabric sources are unchanged.

Vivado 2025.2 XSIM passed 13 DMA cases and an independent generated custom-role/asymmetric fixture; compile/elaboration/simulation exit zero and exact decoded standalone PASS markers are recorded in native_20261006_162123. Independent source review and Verilator lint found no blocking issue in the legal scope (native_run_001/independent_review.md). Current sources match both simulator and synthesis manifests.

Vivado OOC synthesis for native_test_bank_subsystem, xczu7ev-ffvc1156-2-e, aclk 5ns passed: 129 LUT, 416 FF, 2 RAMB36, 2 URAM288, 0 DSP, no blackboxes and no synthesis errors/critical warnings. Reports and checkpoint are in native_ooc_001. Synthesized estimates: WNS3.418ns/TNS0, WHS0.065ns/THS0, WPWS1.800ns/TPWS0, no failing endpoints. These do not establish timing closure: clock source context is absent (Timing38-242), external port delays are missing (TIMING18), and the netlist is unplaced/unrouted. DRC reports no checks found under its partial OOC rule scope; methodology reports819 missing-delay checks. No congestion or board evidence exists.

Simulation/synthesis was run, but timing was not fully verified.

Provided controller informs controller_binding.md: acquisition/release accepted must be sampled at the request edge; completion roles/banks are saved until read drain and release, END drains all outstanding operations. The supplied controller itself and target models were not compiled or integrated. Generated compute wrappers own arbitration and invalid nonselected-source handling; the custom-role fixture checks its single-source scheduling assumption. Every target revision requires fresh module/controller/fabric evidence.

Machine-readable exact identity and results: validation_summary.json.
