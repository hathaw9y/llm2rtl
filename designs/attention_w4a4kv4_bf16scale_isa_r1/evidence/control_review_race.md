# Historical controller release/commit race (P1)

`control_final002` must not be promoted. An independent source-bound XSIM reproduction confirms that a native memory fault can clear ownership and commit the destination before the controller observes error 7.

The exact historical manifest SHA256 is `7b948da716dc7e88dc8bafe18d82299205e5c712a9b78b75012e564649ef83ce`; wrapper SHA256 is `a0a0cb44b9cb8e2a6848b86eee8ea543a607a1b40ef087d390394096c4e82d0d`. The reproduction compiles immutable `control_final002/source_snapshot` RTL, checks every original snapshot identity, and uses only an independently modified temporary testbench. Repository RTL/tests/scripts were not modified.

Each case starts with clean MM2S ownership of bank 18 and all five legal descriptor payload words accepted. Bad requests assert neither ready nor physical memory enable.

| Case | Fault timing | Observation after release edge |
| --- | --- | --- |
| 0 | Unauthorized MM2S bank 17 request on matching completion edge | busy=00000, valid=40000; error 7 subsequently |
| 1 | Bank 18 address equal to capacity_words on RELEASE edge | busy=00000, valid=40000; error 7 subsequently |
| 2 | Unauthorized MM2S bank 17 request on RELEASE edge | busy=00000, valid=40000; error 7 subsequently |

The shared router error is registered; the historical wrapper registers it again. Range errors also reach the public error after the sampling edge. Accepted release and destination commit can therefore precede fault detection. Immediate raw request bank/range/owner checks and immediate registered-child error visibility must inhibit same-edge acquisition, release and physical requests; fault state must preserve ownership and invalid destination until coordinated reset.

Raw compile/elaboration/simulation logs, exact decoded traces, independent testbench and reproduction driver are preserved in `control_review_race_repro/`. Simulation exit is 0 and the exact marker is `CONTROL_REVIEW_REPRO_CONFIRMED`: this certifies reproduction of the failure, **not** an acceptance PASS. The driver uses its original unique `/tmp/control_latefault_independent` path, so rerunning requires an unused output path. `control_review_race.json` binds preserved files by SHA256.

This report is immutable historical blocker evidence. Corrected candidate acceptance will be recorded separately in `control_review.md/json` with new source pins and regression evidence. Math and executor child acceptance is not assessed by this negative controller test.
