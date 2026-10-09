`timescale 1ns/1ps
module attention_tensor_bank_subsystem (
  input logic aclk, aresetn,
  input logic [18:0] bank_acquire_valid, bank_release_valid,
  input logic [18:0][2:0] bank_acquire_port, bank_release_port,
  output logic [18:0] bank_busy,
  output logic [18:0][2:0] bank_owner_port,
  output logic [18:0] bank_acquire_accepted, bank_release_accepted,
  output logic bank_error,
  input logic mm2s_write_valid,
  output logic mm2s_write_ready,
  input logic [4:0] mm2s_write_bank,
  input logic [31:0] mm2s_write_addr,
  input logic [127:0] mm2s_write_data,
  input logic [15:0] mm2s_write_strb,
  input logic s2mm_read_valid,
  output logic s2mm_read_ready,
  input logic [4:0] s2mm_read_bank,
  input logic [31:0] s2mm_read_addr,
  output logic s2mm_rsp_valid,
  output logic [4:0] s2mm_rsp_bank,
  output logic [127:0] s2mm_rsp_data,
  input logic src0_read_valid,
  output logic src0_read_ready,
  input logic [4:0] src0_read_bank,
  input logic [31:0] src0_read_addr,
  output logic src0_rsp_valid,
  output logic [4:0] src0_rsp_bank,
  output logic [127:0] src0_rsp_data,
  input logic src1_read_valid,
  output logic src1_read_ready,
  input logic [4:0] src1_read_bank,
  input logic [31:0] src1_read_addr,
  output logic src1_rsp_valid,
  output logic [4:0] src1_rsp_bank,
  output logic [127:0] src1_rsp_data,
  input logic dst_write_valid,
  output logic dst_write_ready,
  input logic [4:0] dst_write_bank,
  input logic [31:0] dst_write_addr,
  input logic [127:0] dst_write_data,
  input logic [15:0] dst_write_strb
);
  import attention_tensor_config_pkg::*;
  // Explicit index mapping preserves bank ID despite opposite packed ranges.
  logic [0:18] acquire_w, release_w, busy_w;
  logic [0:18][2:0] acquire_port_w, release_port_w, owner_w;
  logic acquire_ok_w, release_ok_w, ownership_error_w, router_error_w;
  logic bank_error_r, request_fault_w;
  logic [2:0] unused_ownership_error_code, unused_router_error_code, unused_router_error_owner;
  logic [4:0] unused_router_error_bank;
  logic [0:18] mem_ena, mem_enb;
  logic [0:18][15:0] mem_wea;
  logic [0:18][31:0] mem_addra, mem_addrb;
  logic [0:18][127:0] mem_dina, mem_doutb;
  logic unused_psum_read_ready, unused_psum_rsp_valid;
  logic [4:0] unused_psum_rsp_bank;
  logic [127:0] unused_psum_rsp_data;
  logic mm2s_range_w, mm2s_ready_w;
  logic s2mm_range_w, s2mm_ready_w;
  logic src0_range_w, src0_ready_w;
  logic src1_range_w, src1_ready_w;
  logic dst_range_w, dst_ready_w;
  for(genvar i=0;i<19;i++) begin : g_owner_map
    assign bank_busy[i]=busy_w[i];
    assign bank_owner_port[i]=owner_w[i];
  end
  always_comb begin
    acquire_ok_w=aresetn && !bank_error;
    release_ok_w=aresetn && !bank_error;
    for(int b=0;b<19;b++) begin
      if(bank_acquire_valid[b] && (bank_busy[b] || bank_acquire_port[b]==0 || bank_acquire_port[b]>3'd5 || bank_release_valid[b])) acquire_ok_w=0;
      if(bank_release_valid[b] && (!bank_busy[b] || bank_release_port[b]!=bank_owner_port[b] || bank_acquire_valid[b])) release_ok_w=0;
    end
    bank_acquire_accepted=acquire_ok_w ? bank_acquire_valid : '0;
    bank_release_accepted=release_ok_w ? bank_release_valid : '0;
    for(int b=0;b<19;b++) begin
      acquire_w[b]=bank_acquire_accepted[b]; release_w[b]=bank_release_accepted[b];
      acquire_port_w[b]=bank_acquire_port[b]; release_port_w[b]=bank_release_port[b];
    end
  end
  // Parallel static bank decode combines capacity and permission in each
  // term. Full-width addresses and bank IDs remain checked before acceptance.
  function automatic logic request_legal(input logic [4:0] bank,
    input logic [31:0] addr, input logic [2:0] role,
    input logic [18:0] busy, input logic [18:0][2:0] owner);
    logic [18:0] legal;
    for(int b=0;b<19;b++)
      legal[b]=(bank==5'(b)) && (addr<capacity_words(5'(b))) &&
        busy[b] && (owner[b]==role);
    return |legal;
  endfunction
  assign mm2s_range_w=request_legal(mm2s_write_bank,mm2s_write_addr,3'd1,bank_busy,bank_owner_port);
  assign mm2s_write_ready=aresetn && !bank_error && mm2s_range_w && mm2s_ready_w;
  assign s2mm_range_w=request_legal(s2mm_read_bank,s2mm_read_addr,3'd2,bank_busy,bank_owner_port);
  assign s2mm_read_ready=aresetn && !bank_error && s2mm_range_w && s2mm_ready_w;
  assign src0_range_w=request_legal(src0_read_bank,src0_read_addr,3'd3,bank_busy,bank_owner_port);
  assign src0_read_ready=aresetn && !bank_error && src0_range_w && src0_ready_w;
  assign src1_range_w=request_legal(src1_read_bank,src1_read_addr,3'd4,bank_busy,bank_owner_port);
  assign src1_read_ready=aresetn && !bank_error && src1_range_w && src1_ready_w;
  assign dst_range_w=request_legal(dst_write_bank,dst_write_addr,3'd5,bank_busy,bank_owner_port);
  assign dst_write_ready=aresetn && !bank_error && dst_range_w && dst_ready_w;
  // Raw-request faults inhibit ownership acknowledgements and all physical
  // accesses on this edge, independently of ready and gated router valid.
  assign request_fault_w=(mm2s_write_valid && !mm2s_range_w) ||
    (s2mm_read_valid && !s2mm_range_w) ||
    (src0_read_valid && !src0_range_w) ||
    (src1_read_valid && !src1_range_w) ||
    (dst_write_valid && !dst_range_w);
  assign bank_error=bank_error_r || ownership_error_w || router_error_w || (aresetn && request_fault_w);
  always_ff @(posedge aclk) begin
    if(!aresetn) bank_error_r<=1'b0;
    else if(ownership_error_w || router_error_w || request_fault_w ||
      ((|bank_acquire_valid) && !acquire_ok_w) || ((|bank_release_valid) && !release_ok_w)) bank_error_r<=1'b1;
  end
  bank_ownership_table #(.BANK_NUM(19),.PORT_ROLE_WIDTH(3)) u_ownership (
    .aclk(aclk),.aresetn(aresetn),.acquire_valid(acquire_w),.acquire_port(acquire_port_w),
    .release_valid(release_w),.release_port(release_port_w),.bank_busy(busy_w),
    .bank_owner_port(owner_w),.ownership_error(ownership_error_w),.ownership_error_code(unused_ownership_error_code)
  );
  bank_port_router #(.BANK_NUM(19),.BANK_NUM_WIDTH(5),.PORT_ROLE_WIDTH(3),
    .ADDR_WIDTH(32),.WRITE_DATA_WIDTH(128),.READ_DATA_WIDTH(128),.READ_LATENCY(3)) u_router (
    .aclk(aclk),.aresetn(aresetn),.bank_busy(busy_w),.bank_owner_port(owner_w),
    .mm2s_write_valid(mm2s_write_valid && !bank_error && aresetn),
    .mm2s_write_ready(mm2s_ready_w),
    .mm2s_write_bank(mm2s_write_bank),
    .mm2s_write_addr(mm2s_write_addr),
    .mm2s_write_data(mm2s_write_data),
    .mm2s_write_strb(mm2s_write_strb),
    .s2mm_read_valid(s2mm_read_valid && !bank_error && aresetn),
    .s2mm_read_ready(s2mm_ready_w),
    .s2mm_read_bank(s2mm_read_bank),
    .s2mm_read_addr(s2mm_read_addr),
    .s2mm_rsp_valid(s2mm_rsp_valid),
    .s2mm_rsp_bank(s2mm_rsp_bank),
    .s2mm_rsp_data(s2mm_rsp_data),
    .gemm_act_read_valid(src0_read_valid && !bank_error && aresetn),
    .gemm_act_read_ready(src0_ready_w),
    .gemm_act_read_bank(src0_read_bank),
    .gemm_act_read_addr(src0_read_addr),
    .gemm_act_rsp_valid(src0_rsp_valid),
    .gemm_act_rsp_bank(src0_rsp_bank),
    .gemm_act_rsp_data(src0_rsp_data),
    .gemm_wgt_read_valid(src1_read_valid && !bank_error && aresetn),
    .gemm_wgt_read_ready(src1_ready_w),
    .gemm_wgt_read_bank(src1_read_bank),
    .gemm_wgt_read_addr(src1_read_addr),
    .gemm_wgt_rsp_valid(src1_rsp_valid),
    .gemm_wgt_rsp_bank(src1_rsp_bank),
    .gemm_wgt_rsp_data(src1_rsp_data),
    .gemm_psum_write_valid(dst_write_valid && !bank_error && aresetn),
    .gemm_psum_write_ready(dst_ready_w),
    .gemm_psum_write_bank(dst_write_bank),
    .gemm_psum_write_addr(dst_write_addr),
    .gemm_psum_write_data(dst_write_data),
    .gemm_psum_write_strb(dst_write_strb),
    .gemm_psum_read_valid(1'b0),
    .gemm_psum_read_ready(unused_psum_read_ready),
    .gemm_psum_read_bank(5'd0),
    .gemm_psum_read_addr(32'd0),
    .gemm_psum_rsp_valid(unused_psum_rsp_valid),
    .gemm_psum_rsp_bank(unused_psum_rsp_bank),
    .gemm_psum_rsp_data(unused_psum_rsp_data),
    .bank_ena(mem_ena),
    .bank_wea(mem_wea),
    .bank_addra(mem_addra),
    .bank_dina(mem_dina),
    .bank_enb(mem_enb),
    .bank_addrb(mem_addrb),
    .bank_doutb(mem_doutb),
    .router_error(router_error_w),
    .router_error_code(unused_router_error_code),
    .router_error_owner(unused_router_error_owner),
    .router_error_bank(unused_router_error_bank)
  );
  for(genvar b=0;b<19;b++) begin : g_bank
    // Physical depth is a power of two. Raw full-width request legality above
    // prevents high-bit truncation aliases before this bounded BRAM interface.
    localparam int PHYS_ADDR_WIDTH=$clog2(BANK_DEPTHS[b]);
    bram_bank #(.ADDR_WIDTH(PHYS_ADDR_WIDTH),.WRITE_DATA_WIDTH(128),.READ_DATA_WIDTH(128),.WRITE_DEPTH(64'(BANK_DEPTHS[b])),.READ_LATENCY(3)) u_memory (
      .aclk(aclk),.aresetn(aresetn),.ena(mem_ena[b]),.wea(mem_wea[b]),.addra(mem_addra[b][PHYS_ADDR_WIDTH-1:0]),.dina(mem_dina[b]),
      .enb(mem_enb[b]),.addrb(mem_addrb[b][PHYS_ADDR_WIDTH-1:0]),.doutb(mem_doutb[b])
    );
  end
endmodule
