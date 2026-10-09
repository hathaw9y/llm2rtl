# Independent controller timing-fix review: PASS, scoped

The updated wrapper is accepted for control-only integration with mocked arithmetic/native DMA peers and actual descriptor ROM, exclusive ownership/router and XPM banks. No current blocker was found. Whole actual-top execution/timing remains separate; this report makes no full Attention or board claim.

Review packet SHA256: `a32e1f3ba8bfcb10c271de6014041103d6a4e27850687f724ebacecfa9f62cbb`. Combined manifest SHA256: `65e04661a21f5ff5c99c650293ebb4315799335ee2bb0d06bcd560956a3de42a`. Wrapper SHA256: `4632129f7cfaecf887a43fc235fe1b23c3ba2e9cdf2a81756755f90ab05c8acb`. Controller remains `c81f8b88ef7df9092759fb5ca3a9f07b1ddab5ffdc4b80dc7f215dac68cb0703`. Only wrapper and additive testbench changed among the 25 bound active files since the previous review. All packet/report pins, current identities, component immutable snapshots and raw evidence hashes were checked independently.

## Change and safety

Parallel static legality terms combine exact bank, full 32-bit address capacity comparison, busy and expected owner. Busy/owner are explicit function arguments, so changing ownership updates combinational legality without relying on implicit global sensitivity. Invalid banks match no term. This replaces dynamic permission selection without changing acceptance rules.

Each physical BRAM port now uses `clog2(BANK_DEPTHS[b])` address bits. The immutable generator chooses minimum 64 and power-of-two depths covering logical capacity, so physical width is at least six bits. Full raw address checks remain before forwarding, and immediate global error suppresses physical enables and the entire acquire/release grant masks. Therefore high bits cannot silently alias into a low physical address. Response/tag latency remains unchanged; already pending responses retain their original pipeline.

Immediate raw faults and registered child errors retain their same-edge grant/forwarding inhibition, with no ready/valid or release-intent feedback loop. The unchanged fault-first controller forbids commit; release valid remains intent and accepted release remains the grant. The historical release/commit race fix is preserved.

## Evidence inspected

`control_alias008` has 38 cases at each command-read latency 1 and 2, with 41 accepted acquisitions and 25 accepted releases. Raw exits are zero and both contain exact standalone `ATTENTION_CONTROL_XSIM_PASS`. Four new tests use rightful owners for SRC0 reads and MM2S writes, with raw addresses `0x40` and `0x80000000` whose physical low bits are zero. They assert immediate no-ready/no-physical-enable/no-grant and five cycles without response, ownership change, destination commit or release-count increment, then error 7 and reset. All four previous completion/RELEASE unauthorized/range tests and the registered-child RELEASE fault test remain and retain ownership/invalid destination.

`control_timing007` provides strict Wall empty-log lint and the actual 5 ns control-shell OOC, with exact standalone `ATTENTION_CONTROL_OOC_PASS` and exit zero. It compiles the same current RTL as `control_alias008`. Its older TB is an immutable historical snapshot and is explicitly excluded from current TB identity; neither OOC nor lint compiles TB. The combined proof does not claim every old simulation manifest entry remains current.

| Metric | Value |
| --- | --- |
| WNS / WHS / WPWS | +0.070 / +0.073 / +1.958 ns |
| Setup / hold / pulse failing endpoints | 0 / 0 / 0 |
| LUT / FF | 6,996 / 3,119 |
| RAMB36 / RAMB18 / DSP / URAM | 38 / 0 / 0 / 0 |
| DRC / methodology checks | 0 / 0 |

Vivado synthesis reports 101 warnings, zero critical warnings and errors; OOC connectivity limitations remain explicit. These are unplaced control-shell estimates with external boundary hold exclusions and a small setup margin, not routed or actual-top timing. The reviewer inspected existing dynamic/lint/OOC artifacts and did not rerun them. Full raw evidence identities and exits are in `control_review_timingfix.json`.

Frozen `control_review.json/md` and historical race evidence are unchanged. Their unchanged-controller contract findings and limitations continue to apply: immutable compiled descriptor profiles, clean completion certifying drained reads/final writes without a read-pending counter, exactly-once transport across finite IDs/bank reuse, and no vendor DataMover/physical DDR/board claim. Actual executor/top integration requires its own current-source acceptance.
