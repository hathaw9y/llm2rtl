# Independent native bank review

Read-only RTL review using fpga-systemverilog and fpga-vivado evidence rules. No RTL, tests, or shared scripts changed by reviewer; this report is the only repository output. Native contract SHA256 f3b841a8e4023e71882f443af8d98dbcea51a8bab0121f3ebaad31d1f15b95cf was verified.

## Result

No blocking finding remains in the reviewed legal DMA-only configuration and scoped generation interface. This is opt-in native split ownership, not a migration of the existing common exclusive-owner contract or existing model fabric.

Ownership acquires are atomic across banks and read/write directions; releases are independently atomic across both directions. Capability, free/conflicting owner, mismatched release, acquire/release overlap, and same-edge/pending reader release prevent the relevant state update. Requests at a release edge use the prior owner. Read pending includes the accepted request and every live response stage. Acquire/release accepted outputs are combinational and reset gated; the controller must sample them at the request acceptance edge and stop/retry requests according to the sampled result.

Router checks capabilities, ownership, and address range before enabling memory. Read address/enable are registered together. Response owner is captured with accepted read rather than recovered from current owner. Total configured latency is four sampled edges (request register one plus memory three), II one, no response backpressure. Reset clears ownership and pending/response tags/valid, with memory contents retained.

Prefix counts only contiguous full-strobe writes beginning at zero, resets on accepted write acquisition, and converts the write-word prefix to complete read words. ADDR_WIDTH+1 supports the maximum representable exclusive end; geometry checks require read/write depths at most 2^ADDR_WIDTH. BRAM supports integral asymmetric widths; URAM is explicitly equal-width. Data bus padding and byte masks are sliced consistently. Geometry guards reject invalid widths/depths/latency; router disables accesses for illegal geometry even in synthesis.

Template contains only named MM2S/S2MM role interfaces. USER routing and output markers permit generated compute requests and captured-tag response assignments without multiple drivers. Package geometry/masks/mappings must be edited in the generated package, not solely appended at USER_CONFIG. Generated wrappers must arbitrate competing sources and surface invalid nonselected requests; a single selected per-bank router cannot observe overwritten requests. The custom probe fixture expressly requires a single-source scheduler and fails simultaneous DMA/probe requests in simulation.

Controller binding documentation correctly requires storing outstanding command bank/role/tag and using saved roles for release. Completion must be retained until all relevant reads drain and release is accepted; END drains all outstanding commands, owners, responses, and saved releases. Provided controller itself is not compiled or validated here.

## Findings resolved during review

- URAM child initially used nonexistent wrapper parameter names. It now binds DATA_WIDTH/DEPTH and rejects asymmetric URAM.
- Template initially lacked name placeholders expected by materialization; placeholders now match script.
- DMA ready initially could be inherited from a selected custom request. Ready now requires selected owner to match DMA.
- One procedural block previously combined request selection and ready feedback, producing Verilator UNOPTFLAT warnings. Ready/response continuous assignments and USER_OUTPUTS now separate those paths.
- Geometry, mapping uniqueness/range/width, and reserved role-zero guards were added.
- Tests now include cross-direction pending release atomicity, captured response tag after external current-owner change, capable wrong-owner access, and controller-facing pending/acceptance sampling.

## Checks actually performed

Reviewer independently ran Verilator --lint-only -Wall -Wno-fatal on freshly materialized DMA-only package/top, all three generic children, and existing memory interface stubs, top review_bank_subsystem. Exit 0. Remaining warnings are filename/package mismatch and intentionally unused/undriven memory interface stubs. No WIDTH, LATCH, MULTIDRIVEN, or UNOPTFLAT warnings remain. This does not establish physical memory behavior. Local run files: /tmp/native_review_20261006/lint.log and lint.exit.

Reviewer inspected, but did not execute, final XSIM evidence native_20261006_162123. All manifest hashes match current contents at review time. Compile, base elaboration/simulation, and extension elaboration/simulation each exit 0. Decoded standalone markers NATIVE_BANK_XSIM_PASS and NATIVE_EXTENSION_XSIM_PASS were present. Base reports 13 cases, 25 observed responses, 26 accepted reads (one outstanding read intentionally cancelled by reset). Extension covers custom role ports, asymmetric 128-bit writes/256-bit reads and prefix flooring, ownership transfer/demux, and generic router wrong-owner/captured-tag tests. Actual tool is Vivado 2025.2.

Legacy bank_subsystem.sv SHA256 d5352d4676c81746284abbbb475bc25b11fd42a25a737eb2d924456f3185d522 and execution_fabric.sv SHA256 9fed04e1dc11d3d530d6ba51623ad6d8112b1d890420d68e07a66c813608e56d match their existing source manifests, confirming these RTL sources remain unchanged.

## Limits

No reviewer-run XSIM, synthesis, placement/routing, board execution, or controller/model integration. OOC timing/resource evidence, if completed separately, requires its own exact manifest and stage assessment. No timing closure or board deployment claim. The default bank sizes are illustrative, not a validated model layout. Native same-edge write/read is staggered physically by read-address registration; later physical read/write collisions, particularly URAM, remain scheduler/vendor concerns. No claim covers unsupported memory types, arbitrary invalid generated packages, or every generated compute arbitration policy.

## Reviewed RTL identity

- `ip/infrastructure/bank_subsystem/rtl/bank_native_memories.sv`: `0a78e2526e6f3076b9b4f7bf7afafb09c51eba43a9a42b1ea485aff1a7ed81bd`
- `ip/infrastructure/bank_subsystem/rtl/bank_native_ownership.sv`: `7a0db8f7773074163d6228fcb632bdbfd10dfbcebd23e62306c3353f8fc1eb2a`
- `ip/infrastructure/bank_subsystem/rtl/bank_native_router.sv`: `724ca73202ee9a01961ab5858cb5ccc8c6ea8355393500818b51fa7bd9009129`
- `ip/infrastructure/bank_subsystem_template/rtl/bank_config_pkg.sv.tpl`: `684deb932e98cd81d85a682d178efca0e92bb5d8ac98986341ba2ceb6fcf1b97`
- `ip/infrastructure/bank_subsystem_template/rtl/bank_subsystem.sv.tpl`: `aec10252c74b4aa21c959b3628fbf4ffdc08f8625be704930e99b25efbfa3b93`
