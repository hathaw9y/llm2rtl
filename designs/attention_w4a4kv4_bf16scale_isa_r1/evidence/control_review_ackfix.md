# Independent atomic-ack timing review: PASS, scoped

The current controller/wrapper are accepted for control-only proof with mocked arithmetic/native DMA peers and actual descriptor ROM, exclusive ownership/router and XPM banks. No current blocker remains. Whole actual-top timing/execution and board deployment require separate acceptance.

Review packet SHA256: `42f68d081d7c714fbec142e79570ba648f7e78380475bdaf734933be0e91f7b5`. Combined manifest SHA256: `70f0ed6ee72b5f950958e8bc01e2a9aab7517fb2cd8c78f0c0df3bff527a873a`. Controller SHA256: `309d6e39eb5d8688c23de315181eb32f72bf43fc62c9dd247437edaccaa06373`; wrapper SHA256: `2d1be00ab69792120424b42b39d4f714cea3da9c166f4544bad9c24bb24f58d8`. All 25 active files, immutable `control_timing010` snapshots and frozen packet/report/component evidence pins match. Only controller and wrapper changed since the previous scoped review; tests/scripts/contracts/shared children are unchanged.

## Equivalence and safety

Wrapper acquisition/release legality is expressed as 19 parallel per-bank violation predicates and global reductions. Each predicate exactly retains the original busy/owner/role/mutual acquire-release checks. A violation at any requested bank suppresses the complete accepted mask, preserving exclusive atomic acquisition/release. Reset and immediate bank-error gating are unchanged.

Controller exact acknowledgement comparisons are partitioned into bit ranges 0–4, 5–9, 10–14 and 15–18. The union covers all 19 bits exactly once, including unrelated accepted bits outside the expected mask. An independent exhaustive Boolean check over all 524,288 possible XOR mismatch patterns found the OR of chunk predicates identical to the full nonzero mismatch test. This narrow check establishes the partition identity, not full RTL simulation. Both acquisition and release retain their original same-edge fault branches; no state, latency or ABI changes were introduced.

The existing raw-completion release-intent blocker, saved-owner checks and fault-first sequential no-commit path remain. Immediate full-bank/full-32-bit-address/owner checks and current child errors continue to block grants and physical forwarding. High address bits cannot alias into the narrowed physical BRAM ports. No new ready/valid or grant feedback was introduced. Historical race reports and earlier accepted reviews are preserved unchanged.

## Current proof inspected

Both command-read latencies 1 and 2 in `control_timing010` report 38 cases, 41 accepted acquisitions and 25 accepted releases, with exact standalone `ATTENTION_CONTROL_XSIM_PASS` and exits zero. Four rightful-owner high-address read/write alias cases and all five completion/RELEASE/registered-child fault retention markers are present in each run. Strict Wall lint has an empty log and exit zero.

Vivado 2025.2 actual control-shell OOC at the original 5 ns clock exits zero with exact standalone `ATTENTION_CONTROL_OOC_PASS`:

| Metric | Value |
| --- | --- |
| WNS / WHS / WPWS | +0.405 / +0.073 / +1.958 ns |
| Setup / hold / pulse failing endpoints | 0 / 0 / 0 |
| LUT / FF | 6,945 / 3,119 |
| RAMB36 / RAMB18 / DSP / URAM | 38 / 0 / 0 / 0 |

The reviewer independently inspected existing simulation, lint and OOC artifacts rather than rerunning them. Full identities, exact exit values and the mask-partition check are recorded in `control_review_ackfix.json`.

Acceptance remains bounded to immutable descriptor profiles and issuer completion certifying drained reads/final writes. Exactly-once transport is required across bank reuse and finite IDs. Unplaced control-shell OOC with external hold exclusions does not prove actual-top or routed timing. No vendor DataMover, physical DDR, whole Attention or board execution is accepted by this report.
