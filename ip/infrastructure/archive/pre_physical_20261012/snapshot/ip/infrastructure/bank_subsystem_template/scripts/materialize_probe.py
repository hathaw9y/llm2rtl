"""Example Agent-owned extension: arbitrary probe reader and asymmetric BRAM."""
def materialize_probe(base, generated):
    pkg = (base / 'rtl/bank_config_pkg.sv.tpl').read_text()
    top = (base / 'rtl/bank_subsystem.sv.tpl').read_text()
    for before, after in [('{{PACKAGE_NAME}}','native_extension_config_pkg'), ('bank_native_config_pkg','native_extension_config_pkg')]:
        pkg = pkg.replace(before, after);top=top.replace(before,after)
    top=top.replace('{{MODULE_NAME}}','native_extension_bank_subsystem').replace('module bank_subsystem','module native_extension_bank_subsystem')
    pkg=pkg.replace('MAX_DATA_WIDTH = 128','MAX_DATA_WIDTH = 256').replace("MEMORY_TYPES [0:BANK_NUM-1] = '{1,2}","MEMORY_TYPES [0:BANK_NUM-1] = '{1,1}")
    pkg=pkg.replace("READ_WIDTHS [0:BANK_NUM-1] = '{128,128}","READ_WIDTHS [0:BANK_NUM-1] = '{256,256}").replace("WRITE_DEPTHS [0:BANK_NUM-1] = '{64,4096}","WRITE_DEPTHS [0:BANK_NUM-1] = '{64,64}")
    pkg=pkg.replace('S2MM_DATA_WIDTH = 128','S2MM_DATA_WIDTH = 256').replace("RD_CAPABILITIES = '{8'h04,8'h04}","RD_CAPABILITIES = '{8'h04,8'h0c}")
    pkg=pkg.replace('// USER_CONFIG_BEGIN',"// USER_CONFIG_BEGIN\n  localparam logic [ROLE_WIDTH-1:0] OWNER_PROBE = 3'd3;")
    top=top.replace('// USER_PORTS_BEGIN', '''// USER_PORTS_BEGIN
    input logic probe_enb,
    input logic [ADDR_WIDTH-1:0] probe_addrb,
    output logic probe_ready, probe_valid,
    output logic [255:0] probe_doutb,''')
    top=top.replace('// USER_ROUTING_BEGIN', '''// USER_ROUTING_BEGIN
    if (probe_enb || bank_rd_owner_port[0] == OWNER_PROBE) begin
      rd_req_valid[0] = probe_enb;
      rd_req_owner[0] = OWNER_PROBE;
      rd_req_addr[0] = probe_addrb;
    end''')
    top=top.replace('// USER_OUTPUTS_BEGIN', """// USER_OUTPUTS_BEGIN
  assign probe_ready = rd_req_ready[0] && rd_req_owner[0] == OWNER_PROBE;
  assign probe_valid = rd_rsp_valid[0] && rd_rsp_owner[0] == OWNER_PROBE;
  assign probe_doutb = rd_rsp_data[0];
  // This smoke fixture has a single-source scheduler: simultaneous read requests
  // from DMA and probe are forbidden and fail explicitly during simulation.
  always_ff @(posedge aclk)
    if(aresetn && probe_enb && s2mm_bank_enb[0])
      $fatal(1, "probe fixture single-source scheduler violated");""")
    paths = [generated / 'extension_config_pkg.sv', generated / 'extension_bank_subsystem.sv']
    paths[0].write_text(pkg);paths[1].write_text(top)
    return paths
