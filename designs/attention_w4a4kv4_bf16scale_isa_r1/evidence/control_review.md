# Independent control review: PASS, scoped

`control_final005` is accepted for controller/control-only integration with mocked arithmetic and native DMA peers and an actual descriptor ROM, exclusive ownership/router and XPM 19-bank memory pool. No current functional blocker remains. This report does not accept whole Attention execution or board deployment.

Final review addendum SHA256: `b401f84a5da9ffe0f14cb75d1069e7a14898e185f030dc7344b707542642ff90`. Manifest SHA256: `af813b627b2c72cedb7900574e194f650dd629dabb44d58a8183500147c00c5f`. Controller SHA256: `c81f8b88ef7df9092759fb5ca3a9f07b1ddab5ffdc4b80dc7f215dac68cb0703`; bank wrapper SHA256: `60ee55a918880fd815e1592df9e5ff3eabf3470f23ff309074bde1427b9154e5`. All 25 active sources and immutable snapshot files match their manifest pins; addendum, contracts and implementation reports match exact hashes. Detailed evidence identities and exits are recorded in `control_review.json`.

## Historical blocker and corrected behavior

Independent XSIM reproduction against immutable `control_final002` confirmed three late native-fault release/commit races. Ownership was cleared and bank 18 committed before error 7. That candidate remains blocked; immutable evidence is preserved in `control_review_race.md/json` and `control_review_race_repro/`.

The corrected wrapper checks raw valid/full bank/full 32-bit address/busy/expected owner on all five native interfaces, independently of ready and gated router valid. Immediate faults and current registered child errors inhibit every accepted acquisition/release mask and physical forwarded request. Its sticky register retains the error. The controller presents a release intent independently; actual grant remains fault gated. Fault-first sequential control forbids destination commit and preserves the bank error code before acknowledgement branches. This removes the redundant combinational controller fault-to-release path without delaying fault protection. Parallel constant-bank address comparisons preserve complete range checks. There is no new ready/valid or acquire/release feedback loop.

## Evidence inspected

Both command-read latencies 1 and 2 contain 34 cases, 35 accepted acquisitions and 23 accepted releases. Raw simulation exits are 0, with exact standalone `ATTENTION_CONTROL_XSIM_PASS`. Each includes completion-edge and RELEASE-edge unauthorized/range faults (four combinations), immediate no-grant/no-physical-request checks, saved owner retention, invalid destination and unchanged release count. A separate registered shared-child fault on RELEASE is also retained. Strict Wall lint exits 0 with an empty log; exact-file ascending ABI LITENDIAN and lint-stub-local annotations are scoped explicitly.

Vivado 2025.2 OOC exits 0 with exact `ATTENTION_CONTROL_OOC_PASS`, at the original 5 ns clock for xczu7ev-ffvc1156-2-e:

| Metric | Value |
| --- | --- |
| WNS / WHS / WPWS | +0.070 / +0.073 / +1.958 ns |
| Setup / hold / pulse failing endpoints | 0 / 0 / 0 |
| LUT / FF | 8,895 / 3,119 |
| RAMB36 / RAMB18 / DSP / URAM | 38 / 0 / 0 / 0 |
| DRC / methodology checks | 0 / 0 |

Synthesis contains 101 warnings, 0 critical warnings and 0 errors; OOC connectivity checking limitations are explicit. Failed timing trial `control_final003` and obsolete intent-monitor trial `control_final004` remain historical and are not promoted. The final controller simulations and OOC were inspected independently, not rerun by this reviewer; only the narrow historical failure reproduction was independently executed.

## Contract and implementation audit

Full raw 8-bit bank and 32-bit descriptor identity checks precede narrow indices; DMA has full-width upper/address-alignment, capacity and 33-bit extent guards. Compiled immutable tuple/shape legality and initialized-source checks precede command issue. Atomic exclusive ownership acquisition occurs on the command handshake and validates the complete accepted mask. Saved identities handle matching completion, including zero-cycle status; clean errors release without committing. Successful destination validity requires a matched drained completion and the entire accepted release mask. Duplicate/spurious identities, unclean/native faults and reset paths preserve the required fail-stop semantics; stalled command valid/payload remain stable. Missing END, restart, physical capacity and explicit ascending/descending bank mapping were inspected.

Acceptance is bounded to immutable generated descriptors and issuer completion semantics: no bank read-pending scoreboard exists, so clean completion certifies every memory response consumed, final writes accepted and no further requests. Bank-only DMA status and finite 16-bit compute IDs require exactly-once transport across reuse; arbitrary stale responses across reuse/wrap cannot be distinguished. Actual arithmetic/full ISA verification is separate. Unplaced OOC timing, external boundary hold exclusions and the small 0.070 ns setup margin do not establish routed board timing. No real DataMover, physical DDR or hardware execution is claimed.
