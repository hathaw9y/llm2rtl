# Common HDL module interface contract

This is the project-wide job-control contract for new and revised module
packets. It follows the existing `hdl-module-implementation` Skill. Skills
are not modified by this contract revision.

## Ports and transaction

Required ports are `aclk`, active-low `aresetn`, input `start`, and output
`done`. Public ports have no `_i` or `_o` direction suffixes. `busy` may be
exposed as optional status; it is not a required handshake signal.

All transitions below are sampled on rising `aclk` edges:

1. After reset, `done` is low. The caller presents valid job configuration
   and asserts `start` while the callee is idle.
2. The callee accepts the request once. The caller holds `start` high and
   job configuration stable throughout execution. An active request cannot
   enqueue or restart a job while the callee is executing or awaiting release.
3. On completion, the callee asserts `done` and keeps it high until the caller
   deasserts `start`. Result/status outputs remain stable while `done` is high.
4. After observing `done`, the caller deasserts `start`. The callee then clears
   `done`; the caller observes `done` low before issuing the next request.

Deasserting `start` before completion is outside the normal transaction
contract and must not be used as cancellation. Reset aborts an outstanding
transaction and clears `done`; reset synchronization follows the module's
clock/reset contract. Job configuration is distinct from dynamic memory,
AXI, and stream response signals, which obey their own protocols.

## Scheduler and transport boundaries

A scheduler follows the same protocol independently for each child and waits
for release before reusing it. Independent completion events must be retained
until all required barriers complete. A host register write may initiate a
job, but its wrapper must convert that event into the held-start transaction.
DataMover Engine command/stream valid-ready and vendor AXI DataMover status protocols
are unchanged; this contract governs module job control, not bus transactions.

## Existing implementations and evidence

Existing module interface contracts and reports describe the RTL revision
they were written for. A module with pulse-based `done` is a legacy protocol
variant, not automatically compliant with this common contract. Existing
`job_control` lists in the IP registry are port inventories, not proof of
protocol compliance.

Before reusing such a module at a common-protocol boundary, explicitly declare
and verify an adapter (one downstream request pulse, captured completion,
upstream held `done`, and release/rearm), or revise the RTL and its module
contract together. Do not relabel old RTL or evidence as compliant by editing
metadata alone. Integration packets must identify each child's protocol and
any adapter. Existing verification remains scoped to its original sources
and protocol; changed sources require fresh relevant verification.

## Required verification coverage

Check one accepted request, multi-cycle held `start`, stable configuration,
completion held until release, stable results while `done` is high, no repeated
execution while awaiting release, release followed by another job without
reset, and reset during execution or completion. Mixed-protocol integration
also checks that no request or completion is lost or duplicated.
