`timescale 1ns/1ps
module attention_descriptor_rom (
    input logic aclk, aresetn,
    input logic desc_lookup_valid,
    input logic [4:0] desc_dst_bank, desc_src0_bank, desc_src1_bank,
    output logic desc_resp_valid,
    output logic [255:0] desc_dst, desc_src0, desc_src1,
    output logic [5:0] ctx_tokens, ctx_query_count,
    output logic [2:0] ctx_heads,
    output logic [6:0] ctx_head_dim,
    output logic ctx_causal,
    output logic [31:0] ctx_qk_factor,
    input logic [4:0] query_index,
    output logic [4:0] query_value
);
  import attention_tensor_config_pkg::*;
  assign ctx_tokens=CTX_TOKENS;
  assign ctx_heads=CTX_HEADS;
  assign ctx_head_dim=CTX_HEAD_DIM;
  assign ctx_query_count=CTX_QUERY_COUNT;
  assign ctx_causal=CTX_CAUSAL;
  assign ctx_qk_factor=CTX_QK_FACTOR;
  assign query_value=attention_tensor_config_pkg::query_value(query_index);
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      desc_resp_valid<=1'b0;
      desc_dst<='0; desc_src0<='0; desc_src1<='0;
    end else begin
      desc_resp_valid<=desc_lookup_valid;
      if(desc_lookup_valid) begin
        desc_dst<=get_descriptor(desc_dst_bank);
        desc_src0<=get_descriptor(desc_src0_bank);
        desc_src1<=get_descriptor(desc_src1_bank);
      end
    end
  end
endmodule
