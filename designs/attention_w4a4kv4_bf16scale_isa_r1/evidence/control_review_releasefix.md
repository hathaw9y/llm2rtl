# Independent controller RELEASE timing review: PASS, scoped

The current controller/wrapper are accepted for the control-only proof with mocked arithmetic/native DMA peers and actual descriptor ROM, exclusive ownership/router and XPM banks. No current blocker was found. This report does not accept whole actual-top execution/timing or board deployment.

Review packet SHA256: `07be5ab721a6aee00da902e01eea99dd71a09c1aaa21ae380fa31b51b2ffa9e1`. Combined manifest SHA256: `57a9fef33387fd1de345117a9d9d6aeb86d94ddc9b70741536e791ec1650fac4`. Controller SHA256: `4ffe5101fd4f711e1f9f658ce14f6212763f80b192bf6a3d3e3d17e2446930c7`; wrapper unchanged at `4632129f7cfaecf887a43fc235fe1b23c3ba2e9cdf2a81756755f90ab05c8acb`. All 25 current sources and `control_timing009` immutable snapshots match. Every frozen packet/report and component evidence pin was independently checked. Only controller release intent and its comments changed since the preceding accepted wrapper review.

## Equivalence and fault protection

In reset-active `RELEASE && !halted`, every response-ready is high and command fire is false. Any MM2S, S2MM or compute completion valid is therefore unsolicited and makes the original `bad_response` true. Directly OR-ing these three raw valid signals to suppress release intent is equivalent here; it avoids the unnecessary bank/ID/count decode path. Outside this state, release intent remains zero. Full identity checking and fault-first sequential error handling remain unchanged.

Owner matching no longer suppresses the intent. The wrapper still checks every saved release role against current busy/owner and rejects the entire accepted mask on any mismatch. The controller's RELEASE sequential branch still checks both owner match and complete accepted mask before destination commit. Consequently a mismatched intent cannot release an owner or commit a destination. Native immediate-fault inhibition of grants and physical requests remains unchanged, as do first-error handling and stalled command valid/payload.

The preceding full 32-bit native address guard, parallel per-bank legality with explicit busy/owner function arguments and bounded physical BRAM port slicing remain intact. No new raw-valid/ready/release feedback path was introduced. Historical race evidence and previous reviews are preserved unchanged.

## Current evidence

`control_timing009` is one all-mode proof with current RTL, tests and scripts, avoiding the previous split-TB identity caveat. Both command-read latencies 1 and 2 report 38 cases, 41 accepted acquisitions and 25 accepted releases; exits are zero and exact standalone `ATTENTION_CONTROL_XSIM_PASS` is present once each. Four rightful-owner high-address alias tests and all five completion/RELEASE/registered-child fault retention checks have exact markers in both runs. Strict Wall lint has an empty log and exit zero.

Raw Vivado 2025.2 5 ns control-shell OOC exits zero and contains exact standalone `ATTENTION_CONTROL_OOC_PASS`:

| Metric | Value |
| --- | --- |
| WNS / WHS / WPWS | +0.219 / +0.071 / +1.958 ns |
| Setup / hold / pulse failing endpoints | 0 / 0 / 0 |
| LUT / FF | 6,978 / 3,119 |
| RAMB36 / RAMB18 / DSP / URAM | 38 / 0 / 0 / 0 |

The reviewer inspected raw simulation/lint/OOC evidence and did not rerun them. Exact identities and all exit values are in `control_review_releasefix.json`.

Scope remains control-only with immutable descriptors and issuer completion certifying drained reads/final writes. Exactly-once transport is required across bank reuse and finite command IDs. Unplaced OOC estimates and external hold exclusions do not establish actual-top or routed timing. Vendor DataMover, physical DDR, full Attention and hardware execution require separate acceptance.
