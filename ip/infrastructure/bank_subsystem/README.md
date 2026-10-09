# bank_subsystem

`bank_subsystem` structurally composes the frozen ownership table, sparse native-width
router, and four XPM-backed memory banks. It does not include a dispatcher, DMA IP,
GEMM arithmetic, board wrapper, or bitstream.

Ownership request vectors are one-cycle pulses. The integration capability gate accepts
only the owner/bank pairs declared by `bank_config_pkg`; an invalid acquire or release
vector is rejected atomically. Child ownership/router errors remain visible and the
combined subsystem status preserves the first error until reset.

Bank 1 uses 128-bit write words and 256-bit read words. XPM simulation establishes the
read packing as `{write_addr[2*n+1], write_addr[2*n]}`.

Run module integration simulation with `scripts/run_xsim.sh`, and isolated 200 MHz OOC
synthesis with `scripts/run_ooc.sh`.

## Native generation path

For new designs, use `../bank_subsystem_template/`: only MM2S/S2MM are fixed.
Agents generate compute-specific ports and routing in `designs/<revision>/rtl/`.
The `rtl/bank_native_*.sv` children separately implement directional ownership,
generic native routing, and configured memories. Their scoped contract is
`contracts/native_v2.json`; the old top and reports above remain the fixed-role
example and do not verify the new path. The native contract uses split read/write
ownership and therefore requires a matching design-specific dispatcher/fabric;
it is not interchangeable with the current common exclusive ownership interface.
