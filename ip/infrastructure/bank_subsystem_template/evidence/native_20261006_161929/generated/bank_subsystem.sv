`timescale 1ns/1ps
import native_test_config_pkg::*;
// Materialize in designs/<revision>/rtl and extend only in that generated copy.
module native_test_bank_subsystem (
    input logic aclk, aresetn,
    input logic [BANK_NUM-1:0] bank_wr_acquire_valid, bank_rd_acquire_valid,
    input logic [BANK_NUM-1:0][ROLE_WIDTH-1:0] bank_wr_acquire_port, bank_rd_acquire_port,
    input logic [BANK_NUM-1:0] bank_wr_release_valid, bank_rd_release_valid,
    input logic [BANK_NUM-1:0][ROLE_WIDTH-1:0] bank_wr_release_port, bank_rd_release_port,
    output logic [BANK_NUM-1:0] bank_wr_busy, bank_rd_busy,
    output logic [BANK_NUM-1:0][ROLE_WIDTH-1:0] bank_wr_owner_port, bank_rd_owner_port,
    input logic mm2s_bank_ena [0:MM2S_BANK_COUNT-1],
    input logic [ADDR_WIDTH-1:0] mm2s_bank_addra [0:MM2S_BANK_COUNT-1],
    input logic [MM2S_DATA_WIDTH-1:0] mm2s_bank_dina [0:MM2S_BANK_COUNT-1],
    input logic [MM2S_DATA_WIDTH/8-1:0] mm2s_bank_wea [0:MM2S_BANK_COUNT-1],
    output logic mm2s_bank_ready [0:MM2S_BANK_COUNT-1],
    input logic s2mm_bank_enb [0:S2MM_BANK_COUNT-1],
    input logic [ADDR_WIDTH-1:0] s2mm_bank_addrb [0:S2MM_BANK_COUNT-1],
    output logic [S2MM_DATA_WIDTH-1:0] s2mm_bank_doutb [0:S2MM_BANK_COUNT-1],
    output logic s2mm_bank_read_ready [0:S2MM_BANK_COUNT-1],
    output logic s2mm_bank_valid [0:S2MM_BANK_COUNT-1],
    // USER_PORTS_BEGIN
    // Agents insert design-specific named native compute ports here.
    // USER_PORTS_END
    output logic [BANK_NUM-1:0][ADDR_WIDTH:0] bank_committed_prefix,
    output logic bank_subsystem_error, ownership_error, router_error,
    output logic [2:0] bank_subsystem_error_code, ownership_error_code, router_error_code
);
  logic [BANK_NUM-1:0] wr_req_valid, rd_req_valid, wr_req_ready, rd_req_ready;
  logic [BANK_NUM-1:0][ROLE_WIDTH-1:0] wr_req_owner, rd_req_owner, rd_rsp_owner;
  logic [BANK_NUM-1:0][ADDR_WIDTH-1:0] wr_req_addr, rd_req_addr;
  logic [BANK_NUM-1:0][MAX_DATA_WIDTH-1:0] wr_req_data, rd_rsp_data;
  logic [BANK_NUM-1:0][MAX_DATA_WIDTH/8-1:0] wr_req_strb;
  logic [BANK_NUM-1:0] rd_rsp_valid, read_pending, wr_acquire_accepted;
  logic [BANK_NUM-1:0] bank_ena, bank_enb;
  logic [BANK_NUM-1:0][MAX_DATA_WIDTH/8-1:0] bank_wea;
  logic [BANK_NUM-1:0][ADDR_WIDTH-1:0] bank_addra, bank_addrb;
  logic [BANK_NUM-1:0][MAX_DATA_WIDTH-1:0] bank_dina, bank_doutb;
  // USER_INTERNAL_BEGIN
  // USER_INTERNAL_END
`ifndef SYNTHESIS
  // Fail visibly rather than silently truncating a generated DMA interface.
  initial begin
    if (MM2S_BANK_COUNT < 1 || S2MM_BANK_COUNT < 1)
      $fatal(1, "DMA mapping arrays require at least one endpoint");
    for (int p=0; p<MM2S_BANK_COUNT; p++) begin
      if (MM2S_BANK_IDS[p] < 0 || MM2S_BANK_IDS[p] >= BANK_NUM)
        $fatal(1, "MM2S bank ID out of range");
      else if (WRITE_WIDTHS[MM2S_BANK_IDS[p]] != MM2S_DATA_WIDTH)
        $fatal(1, "MM2S native word width must match mapped bank");
      for (int q=0; q<p; q++)
        if (MM2S_BANK_IDS[p] == MM2S_BANK_IDS[q]) $fatal(1, "duplicate MM2S bank mapping");
    end
    for (int p=0; p<S2MM_BANK_COUNT; p++) begin
      if (S2MM_BANK_IDS[p] < 0 || S2MM_BANK_IDS[p] >= BANK_NUM)
        $fatal(1, "S2MM bank ID out of range");
      else if (READ_WIDTHS[S2MM_BANK_IDS[p]] != S2MM_DATA_WIDTH)
        $fatal(1, "S2MM native word width must match mapped bank");
      for (int q=0; q<p; q++)
        if (S2MM_BANK_IDS[p] == S2MM_BANK_IDS[q]) $fatal(1, "duplicate S2MM bank mapping");
    end
    for (int b=0; b<BANK_NUM; b++) begin
      if (MEMORY_TYPES[b] != 1 && MEMORY_TYPES[b] != 2)
        $fatal(1, "native template uses dense BRAM/URAM banks only");
      if (WR_CAPABILITIES[b][0] || RD_CAPABILITIES[b][0])
        $fatal(1, "role zero must remain reserved");
    end
  end
`endif
  always_comb begin
    wr_req_valid='0; wr_req_owner='0; wr_req_addr='0; wr_req_data='0; wr_req_strb='0;
    rd_req_valid='0; rd_req_owner='0; rd_req_addr='0;
    for (int p=0; p<MM2S_BANK_COUNT; p++) begin
      wr_req_valid[MM2S_BANK_IDS[p]] = mm2s_bank_ena[p];
      wr_req_owner[MM2S_BANK_IDS[p]] = OWNER_MM2S;
      wr_req_addr[MM2S_BANK_IDS[p]] = mm2s_bank_addra[p];
      wr_req_data[MM2S_BANK_IDS[p]] = MAX_DATA_WIDTH'(mm2s_bank_dina[p]);
      wr_req_strb[MM2S_BANK_IDS[p]] = (MAX_DATA_WIDTH/8)'(mm2s_bank_wea[p]);
    end
    for (int p=0; p<S2MM_BANK_COUNT; p++) begin
      rd_req_valid[S2MM_BANK_IDS[p]] = s2mm_bank_enb[p];
      rd_req_owner[S2MM_BANK_IDS[p]] = OWNER_S2MM;
      rd_req_addr[S2MM_BANK_IDS[p]] = s2mm_bank_addrb[p];
      s2mm_bank_doutb[p] = S2MM_DATA_WIDTH'(rd_rsp_data[S2MM_BANK_IDS[p]]);
      s2mm_bank_valid[p] = rd_rsp_valid[S2MM_BANK_IDS[p]] && rd_rsp_owner[S2MM_BANK_IDS[p]] == OWNER_S2MM;
    end
    // USER_ROUTING_BEGIN
    // Generated compute routing arbitrates with DMA using owner/request rules;
    // return valid is selected by captured rd_rsp_owner, never current owner.
    // USER_ROUTING_END
    for (int p=0; p<MM2S_BANK_COUNT; p++)
      mm2s_bank_ready[p] = wr_req_ready[MM2S_BANK_IDS[p]] && wr_req_owner[MM2S_BANK_IDS[p]] == OWNER_MM2S;
    for (int p=0; p<S2MM_BANK_COUNT; p++)
      s2mm_bank_read_ready[p] = rd_req_ready[S2MM_BANK_IDS[p]] && rd_req_owner[S2MM_BANK_IDS[p]] == OWNER_S2MM;
  end
  bank_native_ownership #(.BANK_NUM(BANK_NUM), .ROLE_WIDTH(ROLE_WIDTH),
      .WR_CAPABILITIES(WR_CAPABILITIES), .RD_CAPABILITIES(RD_CAPABILITIES)) u_ownership (
      .aclk(aclk), .aresetn(aresetn), .bank_wr_acquire_valid(bank_wr_acquire_valid),
      .bank_rd_acquire_valid(bank_rd_acquire_valid), .bank_wr_acquire_port(bank_wr_acquire_port),
      .bank_rd_acquire_port(bank_rd_acquire_port), .bank_wr_release_valid(bank_wr_release_valid),
      .bank_rd_release_valid(bank_rd_release_valid), .bank_wr_release_port(bank_wr_release_port),
      .bank_rd_release_port(bank_rd_release_port), .read_pending(read_pending),
      .bank_wr_busy(bank_wr_busy), .bank_rd_busy(bank_rd_busy),
      .bank_wr_owner_port(bank_wr_owner_port), .bank_rd_owner_port(bank_rd_owner_port),
      .wr_acquire_accepted(wr_acquire_accepted), .ownership_error(ownership_error),
      .ownership_error_code(ownership_error_code));
  bank_native_router #(.BANK_NUM(BANK_NUM), .ROLE_WIDTH(ROLE_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
      .MAX_DATA_WIDTH(MAX_DATA_WIDTH), .MEMORY_READ_LATENCY(MEMORY_READ_LATENCY),
      .WRITE_WIDTHS(WRITE_WIDTHS), .READ_WIDTHS(READ_WIDTHS), .WRITE_DEPTHS(WRITE_DEPTHS),
      .WR_CAPABILITIES(WR_CAPABILITIES), .RD_CAPABILITIES(RD_CAPABILITIES)) u_router (
      .aclk(aclk), .aresetn(aresetn), .bank_wr_busy(bank_wr_busy), .bank_rd_busy(bank_rd_busy),
      .bank_wr_owner_port(bank_wr_owner_port), .bank_rd_owner_port(bank_rd_owner_port),
      .wr_req_valid(wr_req_valid), .rd_req_valid(rd_req_valid), .wr_req_owner(wr_req_owner),
      .rd_req_owner(rd_req_owner), .wr_req_addr(wr_req_addr), .rd_req_addr(rd_req_addr),
      .wr_req_data(wr_req_data), .wr_req_strb(wr_req_strb), .wr_req_ready(wr_req_ready),
      .rd_req_ready(rd_req_ready), .rd_rsp_valid(rd_rsp_valid), .rd_rsp_owner(rd_rsp_owner),
      .rd_rsp_data(rd_rsp_data), .read_pending(read_pending), .bank_ena(bank_ena),
      .bank_enb(bank_enb), .bank_wea(bank_wea), .bank_addra(bank_addra),
      .bank_addrb(bank_addrb), .bank_dina(bank_dina), .bank_doutb(bank_doutb),
      .router_error(router_error), .router_error_code(router_error_code));
  bank_native_memories #(.BANK_NUM(BANK_NUM), .ADDR_WIDTH(ADDR_WIDTH),
      .MAX_DATA_WIDTH(MAX_DATA_WIDTH), .MEMORY_READ_LATENCY(MEMORY_READ_LATENCY),
      .MEMORY_TYPES(MEMORY_TYPES), .WRITE_WIDTHS(WRITE_WIDTHS),
      .READ_WIDTHS(READ_WIDTHS), .WRITE_DEPTHS(WRITE_DEPTHS)) u_memories (
      .aclk(aclk), .aresetn(aresetn), .bank_ena(bank_ena), .bank_enb(bank_enb),
      .bank_wea(bank_wea), .bank_addra(bank_addra), .bank_addrb(bank_addrb),
      .bank_dina(bank_dina), .bank_doutb(bank_doutb));
  // Prefix means initialized sequential words during this write epoch. It does
  // not prevent overwrites and does not gate reads. Use a write-word counter
  // before converting to read words, so asymmetric half-words cannot commit early.
  for (genvar b=0; b<BANK_NUM; b++) begin : g_commit
    logic [ADDR_WIDTH:0] written_prefix_r;
    assign bank_committed_prefix[b] = (ADDR_WIDTH+1)'(
        (64'(written_prefix_r)*64'(WRITE_WIDTHS[b]))/64'(READ_WIDTHS[b]));
    always_ff @(posedge aclk) begin
      if (!aresetn || wr_acquire_accepted[b]) written_prefix_r <= '0;
      else if (bank_ena[b] && (&bank_wea[b][WRITE_WIDTHS[b]/8-1:0]) &&
               {1'b0,bank_addra[b]} == written_prefix_r)
        written_prefix_r <= written_prefix_r + (ADDR_WIDTH+1)'(1);
    end
  end
  always_ff @(posedge aclk) begin
    if (!aresetn) begin bank_subsystem_error <= 1'b0; bank_subsystem_error_code <= '0; end
    else if (!bank_subsystem_error) begin
      if (ownership_error) begin bank_subsystem_error <= 1'b1; bank_subsystem_error_code <= 3'd2; end
      else if (router_error) begin bank_subsystem_error <= 1'b1; bank_subsystem_error_code <= 3'd3; end
    end
  end
endmodule
