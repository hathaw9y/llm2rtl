# Parent acceptance: PASS

Parent/root authored no RTL and independently accepted the bounded standalone Attention ISA implementation.
The frozen implementation result remains `VERIFIED_PENDING_INDEPENDENT_INTEGRATION_AUDIT` as a historical
pre-review artifact; this additive acceptance records the completed review without rewriting that evidence.

All 9 current-source profiles passed 52 actual XSIM cases; prefill command latency 2 passed 36 additional cases.
Canonical 21-command and diagnostic 34-command programs compare all 13 computed banks including data,
BF16 scales and padding. Native DMA peers are BFMs; compute/math/XPM memories are real RTL.

All 9 strict lint logs are empty. Lint uses default top parameters 10/1024/1;
simulation/OOC use 6/64/1, and separate latency-2 simulation uses 6/64/2.
Default prefill actual top passed unplaced 5 ns OOC: WNS +0.149 ns, WHS +0.061 ns,
WPWS +1.958 ns, and zero setup/hold/pulse failures. Resources: 16,992 LUT,
7,004 FF, 38 RAMB36, 1 RAMB18 and 8 DSP. Seventeen DSP pipeline warnings and one
RAM output-register methodology advisory remain disclosed.

Independent child reviews and current/snapshot/raw evidence identities are pinned in `parent_acceptance.json`.
The controller author also crosschecked the integration fixture with that authorship disclosed; independent
controller review and final parent audit remain separate. Failed/race trials are retained.

This is scalar RTL with immutable descriptors and bounded dimensions. Full Cartesian maximum shapes,
other-shape resource/timing evidence, routed timing, physical DDR/vendor DMA, board deployment, model
quality, persistent KV cache, RoPE, GQA and whole-model ISA support are outside this acceptance.
