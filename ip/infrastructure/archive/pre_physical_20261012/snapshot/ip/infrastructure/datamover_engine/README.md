# Reusable DataMover Engine source

This is the reusable local-bank transport foundation, not a generated model
accelerator or vendor AXI DataMover implementation. RTL and interface contract
are copied unchanged from the development workspace. Historical build reports
and board examples are intentionally not included.

The scheduler supplies commands and owns recovery policy. The Engine validates
descriptors and completion status, and works with stream/native-bank adapters.
Vendor memory/DMA IP and board connections must be created for the selected target.

`bram_bank` and `uram_bank` are XPM simple-dual-port wrappers. Both default to
three-cycle reads, use word-index addresses, suppress out-of-range enables, and
reset only the read-output pipeline. The XSIM integration path instantiates the
real BRAM wrapper; the Icarus path uses an explicitly selected behavioral fallback.

Run adapter/unit tests with `bash scripts/run_sim.sh`. For the real-child
integration test, see `tb/INTEGRATION.md` and `scripts/run_integration_sim.sh`.
These tests do not establish board timing or physical FPGA acceptance.
