# Bank ownership table template

Reuse the existing `bank_ownership_table` RTL. It already accepts `BANK_NUM` and
`PORT_ROLE_WIDTH`; it does not encode GEMM or another model opcode. The Agent
selects the bank inventory and assigns one nonzero role ID to each executor
operand port after discussing the ISA and module boundaries with the user.

The model binding supplies the role IDs and the allowed role/bank pairs. The
generated dispatcher drives acquire/release vectors, while this unchanged core
stores ownership. The generated fabric must reject invalid role/bank pairs
before they reach the core. Role zero is reserved for no owner.

The [template contract](template_contract.json) pins the reusable source.
Existing module evidence does not prove a new role assignment or integration.
