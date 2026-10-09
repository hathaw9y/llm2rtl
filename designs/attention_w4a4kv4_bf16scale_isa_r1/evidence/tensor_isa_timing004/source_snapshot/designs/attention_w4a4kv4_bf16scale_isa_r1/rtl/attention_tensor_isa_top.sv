`timescale 1ns/1ps
// Actual executor instantiation. Control-only evidence uses an explicitly named mock closure.
module attention_tensor_isa_top #(
  parameter int CMD_ADDR_WIDTH=10, MAX_COMMANDS=1024, CMD_READ_LATENCY=1
)(
  input logic  aclk,
  input logic  aresetn,
  input logic  cmd_dispatcher_start,
  output logic  cmd_dispatcher_busy,
  output logic  cmd_dispatcher_done,
  output logic  cmd_dispatcher_error,
  output logic [7:0] cmd_dispatcher_error_code,
  output logic [CMD_ADDR_WIDTH-1:0] cmd_dispatcher_current_pc,
  output logic  cmd_enb,
  output logic [CMD_ADDR_WIDTH-1:0] cmd_addrb,
  input logic [127:0] cmd_doutb,
  output logic  m_ctrl_mm2s_cmd_valid,
  input logic  m_ctrl_mm2s_cmd_ready,
  output logic [31:0] m_ctrl_mm2s_cmd_addr,
  output logic [22:0] m_ctrl_mm2s_cmd_btt,
  output logic [22:0] m_ctrl_mm2s_cmd_offset,
  output logic [4:0] m_ctrl_mm2s_cmd_bank,
  output logic  m_ctrl_s2mm_cmd_valid,
  input logic  m_ctrl_s2mm_cmd_ready,
  output logic [31:0] m_ctrl_s2mm_cmd_addr,
  output logic [22:0] m_ctrl_s2mm_cmd_btt,
  output logic [22:0] m_ctrl_s2mm_cmd_offset,
  output logic [4:0] m_ctrl_s2mm_cmd_bank,
  input logic  s_ctrl_mm2s_sts_valid,
  output logic  m_ctrl_mm2s_sts_ready,
  input logic [4:0] s_ctrl_mm2s_sts_bank,
  input logic  s_ctrl_mm2s_sts_error,
  input logic  s_ctrl_mm2s_faulted,
  input logic  s_ctrl_s2mm_sts_valid,
  output logic  m_ctrl_s2mm_sts_ready,
  input logic [4:0] s_ctrl_s2mm_sts_bank,
  input logic  s_ctrl_s2mm_sts_error,
  input logic  s_ctrl_s2mm_faulted,
  output logic [18:0] bank_valid,
  input logic  mm2s_write_valid,
  output logic  mm2s_write_ready,
  input logic [4:0] mm2s_write_bank,
  input logic [31:0] mm2s_write_addr,
  input logic [127:0] mm2s_write_data,
  input logic [15:0] mm2s_write_strb,
  input logic  s2mm_read_valid,
  output logic  s2mm_read_ready,
  input logic [4:0] s2mm_read_bank,
  input logic [31:0] s2mm_read_addr,
  output logic  s2mm_rsp_valid,
  output logic [4:0] s2mm_rsp_bank,
  output logic [127:0] s2mm_rsp_data,
  output logic  bank_error,
  output logic [18:0] bank_busy,
  output logic [18:0][2:0] bank_owner_port
);
  logic  compute_cmd_valid;
  logic  compute_cmd_ready;
  logic [15:0] compute_cmd_id;
  logic [7:0] compute_cmd_opcode;
  logic [4:0] compute_cmd_src0;
  logic [4:0] compute_cmd_src1;
  logic [4:0] compute_cmd_dst;
  logic [255:0] compute_cmd_src0_desc;
  logic [255:0] compute_cmd_src1_desc;
  logic [255:0] compute_cmd_dst_desc;
  logic  compute_resp_valid;
  logic  compute_resp_ready;
  logic [15:0] compute_resp_id;
  logic  compute_resp_error;
  logic [7:0] compute_resp_error_code;
  logic  desc_lookup_valid;
  logic [4:0] desc_dst_bank;
  logic [4:0] desc_src0_bank;
  logic [4:0] desc_src1_bank;
  logic  desc_resp_valid;
  logic [255:0] desc_dst;
  logic [255:0] desc_src0;
  logic [255:0] desc_src1;
  logic [18:0] bank_acquire_valid;
  logic [18:0] bank_release_valid;
  logic [18:0][2:0] bank_acquire_port;
  logic [18:0][2:0] bank_release_port;
  logic [18:0] bank_acquire_accepted;
  logic [18:0] bank_release_accepted;
  logic  src0_read_valid;
  logic  src0_read_ready;
  logic [4:0] src0_read_bank;
  logic [31:0] src0_read_addr;
  logic  src0_rsp_valid;
  logic [4:0] src0_rsp_bank;
  logic [127:0] src0_rsp_data;
  logic  src1_read_valid;
  logic  src1_read_ready;
  logic [4:0] src1_read_bank;
  logic [31:0] src1_read_addr;
  logic  src1_rsp_valid;
  logic [4:0] src1_rsp_bank;
  logic [127:0] src1_rsp_data;
  logic  dst_write_valid;
  logic  dst_write_ready;
  logic [4:0] dst_write_bank;
  logic [31:0] dst_write_addr;
  logic [127:0] dst_write_data;
  logic [15:0] dst_write_strb;
  logic [5:0] ctx_tokens;
  logic [5:0] ctx_query_count;
  logic [2:0] ctx_heads;
  logic [6:0] ctx_head_dim;
  logic  ctx_causal;
  logic [31:0] ctx_qk_factor;
  logic [4:0] query_index;
  logic [4:0] query_value;
  attention_tensor_controller #(.CMD_ADDR_WIDTH(CMD_ADDR_WIDTH),.MAX_COMMANDS(MAX_COMMANDS),.CMD_READ_LATENCY(CMD_READ_LATENCY)) u_controller (
    .aclk(aclk),
    .aresetn(aresetn),
    .cmd_dispatcher_start(cmd_dispatcher_start),
    .cmd_dispatcher_busy(cmd_dispatcher_busy),
    .cmd_dispatcher_done(cmd_dispatcher_done),
    .cmd_dispatcher_error(cmd_dispatcher_error),
    .cmd_dispatcher_error_code(cmd_dispatcher_error_code),
    .cmd_dispatcher_current_pc(cmd_dispatcher_current_pc),
    .cmd_enb(cmd_enb),
    .cmd_addrb(cmd_addrb),
    .cmd_doutb(cmd_doutb),
    .m_ctrl_mm2s_cmd_valid(m_ctrl_mm2s_cmd_valid),
    .m_ctrl_mm2s_cmd_ready(m_ctrl_mm2s_cmd_ready),
    .m_ctrl_mm2s_cmd_addr(m_ctrl_mm2s_cmd_addr),
    .m_ctrl_mm2s_cmd_btt(m_ctrl_mm2s_cmd_btt),
    .m_ctrl_mm2s_cmd_offset(m_ctrl_mm2s_cmd_offset),
    .m_ctrl_mm2s_cmd_bank(m_ctrl_mm2s_cmd_bank),
    .m_ctrl_s2mm_cmd_valid(m_ctrl_s2mm_cmd_valid),
    .m_ctrl_s2mm_cmd_ready(m_ctrl_s2mm_cmd_ready),
    .m_ctrl_s2mm_cmd_addr(m_ctrl_s2mm_cmd_addr),
    .m_ctrl_s2mm_cmd_btt(m_ctrl_s2mm_cmd_btt),
    .m_ctrl_s2mm_cmd_offset(m_ctrl_s2mm_cmd_offset),
    .m_ctrl_s2mm_cmd_bank(m_ctrl_s2mm_cmd_bank),
    .s_ctrl_mm2s_sts_valid(s_ctrl_mm2s_sts_valid),
    .m_ctrl_mm2s_sts_ready(m_ctrl_mm2s_sts_ready),
    .s_ctrl_mm2s_sts_bank(s_ctrl_mm2s_sts_bank),
    .s_ctrl_mm2s_sts_error(s_ctrl_mm2s_sts_error),
    .s_ctrl_mm2s_faulted(s_ctrl_mm2s_faulted),
    .s_ctrl_s2mm_sts_valid(s_ctrl_s2mm_sts_valid),
    .m_ctrl_s2mm_sts_ready(m_ctrl_s2mm_sts_ready),
    .s_ctrl_s2mm_sts_bank(s_ctrl_s2mm_sts_bank),
    .s_ctrl_s2mm_sts_error(s_ctrl_s2mm_sts_error),
    .s_ctrl_s2mm_faulted(s_ctrl_s2mm_faulted),
    .compute_cmd_valid(compute_cmd_valid),
    .compute_cmd_ready(compute_cmd_ready),
    .compute_cmd_id(compute_cmd_id),
    .compute_cmd_opcode(compute_cmd_opcode),
    .compute_cmd_src0(compute_cmd_src0),
    .compute_cmd_src1(compute_cmd_src1),
    .compute_cmd_dst(compute_cmd_dst),
    .compute_cmd_src0_desc(compute_cmd_src0_desc),
    .compute_cmd_src1_desc(compute_cmd_src1_desc),
    .compute_cmd_dst_desc(compute_cmd_dst_desc),
    .compute_resp_valid(compute_resp_valid),
    .compute_resp_ready(compute_resp_ready),
    .compute_resp_id(compute_resp_id),
    .compute_resp_error(compute_resp_error),
    .compute_resp_error_code(compute_resp_error_code),
    .desc_lookup_valid(desc_lookup_valid),
    .desc_dst_bank(desc_dst_bank),
    .desc_src0_bank(desc_src0_bank),
    .desc_src1_bank(desc_src1_bank),
    .desc_resp_valid(desc_resp_valid),
    .desc_dst(desc_dst),
    .desc_src0(desc_src0),
    .desc_src1(desc_src1),
    .bank_acquire_valid(bank_acquire_valid),
    .bank_release_valid(bank_release_valid),
    .bank_acquire_port(bank_acquire_port),
    .bank_release_port(bank_release_port),
    .bank_busy(bank_busy),
    .bank_owner_port(bank_owner_port),
    .bank_acquire_accepted(bank_acquire_accepted),
    .bank_release_accepted(bank_release_accepted),
    .bank_error(bank_error),
    .bank_valid(bank_valid)
  );
  attention_descriptor_rom u_descriptors (
    .aclk(aclk),
    .aresetn(aresetn),
    .desc_lookup_valid(desc_lookup_valid),
    .desc_dst_bank(desc_dst_bank),
    .desc_src0_bank(desc_src0_bank),
    .desc_src1_bank(desc_src1_bank),
    .desc_resp_valid(desc_resp_valid),
    .desc_dst(desc_dst),
    .desc_src0(desc_src0),
    .desc_src1(desc_src1),
    .ctx_tokens(ctx_tokens),
    .ctx_query_count(ctx_query_count),
    .ctx_heads(ctx_heads),
    .ctx_head_dim(ctx_head_dim),
    .ctx_causal(ctx_causal),
    .ctx_qk_factor(ctx_qk_factor),
    .query_index(query_index),
    .query_value(query_value)
  );
  attention_tensor_bank_subsystem u_banks (
    .aclk(aclk),
    .aresetn(aresetn),
    .bank_acquire_valid(bank_acquire_valid),
    .bank_release_valid(bank_release_valid),
    .bank_acquire_port(bank_acquire_port),
    .bank_release_port(bank_release_port),
    .bank_busy(bank_busy),
    .bank_owner_port(bank_owner_port),
    .bank_acquire_accepted(bank_acquire_accepted),
    .bank_release_accepted(bank_release_accepted),
    .bank_error(bank_error),
    .mm2s_write_valid(mm2s_write_valid),
    .mm2s_write_ready(mm2s_write_ready),
    .mm2s_write_bank(mm2s_write_bank),
    .mm2s_write_addr(mm2s_write_addr),
    .mm2s_write_data(mm2s_write_data),
    .mm2s_write_strb(mm2s_write_strb),
    .s2mm_read_valid(s2mm_read_valid),
    .s2mm_read_ready(s2mm_read_ready),
    .s2mm_read_bank(s2mm_read_bank),
    .s2mm_read_addr(s2mm_read_addr),
    .s2mm_rsp_valid(s2mm_rsp_valid),
    .s2mm_rsp_bank(s2mm_rsp_bank),
    .s2mm_rsp_data(s2mm_rsp_data),
    .src0_read_valid(src0_read_valid),
    .src0_read_ready(src0_read_ready),
    .src0_read_bank(src0_read_bank),
    .src0_read_addr(src0_read_addr),
    .src0_rsp_valid(src0_rsp_valid),
    .src0_rsp_bank(src0_rsp_bank),
    .src0_rsp_data(src0_rsp_data),
    .src1_read_valid(src1_read_valid),
    .src1_read_ready(src1_read_ready),
    .src1_read_bank(src1_read_bank),
    .src1_read_addr(src1_read_addr),
    .src1_rsp_valid(src1_rsp_valid),
    .src1_rsp_bank(src1_rsp_bank),
    .src1_rsp_data(src1_rsp_data),
    .dst_write_valid(dst_write_valid),
    .dst_write_ready(dst_write_ready),
    .dst_write_bank(dst_write_bank),
    .dst_write_addr(dst_write_addr),
    .dst_write_data(dst_write_data),
    .dst_write_strb(dst_write_strb)
  );
  attention_tensor_executor u_executor (
    .aclk(aclk),
    .aresetn(aresetn),
    .cmd_valid(compute_cmd_valid),
    .cmd_ready(compute_cmd_ready),
    .cmd_id(compute_cmd_id),
    .cmd_opcode(compute_cmd_opcode),
    .cmd_src0(compute_cmd_src0),
    .cmd_src1(compute_cmd_src1),
    .cmd_dst(compute_cmd_dst),
    .cmd_src0_desc(compute_cmd_src0_desc),
    .cmd_src1_desc(compute_cmd_src1_desc),
    .cmd_dst_desc(compute_cmd_dst_desc),
    .resp_valid(compute_resp_valid),
    .resp_ready(compute_resp_ready),
    .resp_id(compute_resp_id),
    .resp_error(compute_resp_error),
    .resp_error_code(compute_resp_error_code),
    .ctx_tokens(ctx_tokens),
    .ctx_query_count(ctx_query_count),
    .ctx_heads(ctx_heads),
    .ctx_head_dim(ctx_head_dim),
    .ctx_causal(ctx_causal),
    .ctx_qk_factor(ctx_qk_factor),
    .query_lookup_index(query_index),
    .query_lookup_value(query_value),
    .src0_read_valid(src0_read_valid),
    .src0_read_ready(src0_read_ready),
    .src0_read_bank(src0_read_bank),
    .src0_read_addr(src0_read_addr),
    .src0_resp_valid(src0_rsp_valid),
    .src0_resp_bank(src0_rsp_bank),
    .src0_resp_data(src0_rsp_data),
    .src1_read_valid(src1_read_valid),
    .src1_read_ready(src1_read_ready),
    .src1_read_bank(src1_read_bank),
    .src1_read_addr(src1_read_addr),
    .src1_resp_valid(src1_rsp_valid),
    .src1_resp_bank(src1_rsp_bank),
    .src1_resp_data(src1_rsp_data),
    .dst_write_valid(dst_write_valid),
    .dst_write_ready(dst_write_ready),
    .dst_write_bank(dst_write_bank),
    .dst_write_addr(dst_write_addr),
    .dst_write_data(dst_write_data),
    .dst_write_strb(dst_write_strb)
  );
endmodule
