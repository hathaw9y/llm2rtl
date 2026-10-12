# Stream/bank adapters

This packet implements the frozen `stream_bank_adapters` contract. The concrete
boundary, which the compact frozen contract did not spell out field-by-field,
uses `s_ctrl_start/done/abort`, 23-bit byte offsets/counts, standard 64-bit AXIS
payload naming, and the valid-ready port names already used by `bank_subsystem`.
MM2S latches a 4-bit bank selector and emits 128-bit writes. S2MM reads fixed
1024-bit native words (bank 3 at integration) and emits 64-bit AXIS beats.

Offsets are bytes. Native bank addresses are word indices: MM2S divides by 16
and S2MM divides by 128. Low-order bytes/beats occupy low-order packed slices.
`aresetn` is synchronous active-low. `done` is held until `start` is low.

This packet does not implement or claim a DataMover command/status engine,
bank ownership, memory, DDR behavior, or board integration.
