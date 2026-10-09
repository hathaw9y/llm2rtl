# Bank ownership table

`bank_ownership_table` stores one module-port-role owner for each local data bank.
All asserted acquire entries and all asserted release entries are separately atomic;
valid disjoint release and acquire groups may commit in one cycle. Bank 0 is legal.

Roles are `1=MM2S_ARBITER`, `2=S2MM_ARBITER`, `3=GEMM_ACT`, `4=GEMM_WGT`, and
`5=GEMM_PSUM`. The table does not route payloads or implement memories or executors.
