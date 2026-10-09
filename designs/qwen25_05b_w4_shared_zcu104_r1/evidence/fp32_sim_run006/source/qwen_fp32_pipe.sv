module qwen_fp32_pipe #(
  parameter integer ID_WIDTH=10
)(
  input logic clk,rst_n,
  input logic cmd_valid,output logic cmd_ready,
  input logic [ID_WIDTH-1:0] cmd_id,
  input logic cmd_multiply,
  input logic [31:0] cmd_a,cmd_b,
  output logic rsp_valid,input logic rsp_ready,
  output logic [ID_WIDTH-1:0] rsp_id,
  output logic [31:0] rsp_data,
  output logic rsp_error
);
  import qwen_fp32_pkg::*;
  logic [5:0] valid_r;
  logic [4:0] multiply_r;
  logic [31:0] a_r,b_r,result_r,mul_result_r,mul_rounded_r;
  logic [ID_WIDTH-1:0] id_r[0:5];
  add_prepare_t prepared_r;
  add_align_t aligned_r;
  add_sum_t sum_r;
  add_norm_t norm_r;
  mul_product_t product_r;
  mul_norm_t mul_norm_r;
  logic advance;
  assign advance=!valid_r[5] || rsp_ready;
  assign cmd_ready=advance && rst_n;
  assign rsp_valid=valid_r[5];assign rsp_data=result_r;assign rsp_id=id_r[5];
  assign rsp_error=(result_r[30:23]==8'hff);
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      valid_r<={valid_r[4:0],cmd_valid};
      multiply_r<={multiply_r[3:0],cmd_multiply};
      // Six stages separate exponent comparison from alignment. Data bubbles
      // may update, but the whole pipeline freezes on response backpressure;
      // validity/identity alone determine observable operations. Avoid merged
      // valid clock enables with thousands of arithmetic-register loads.
      a_r<=cmd_a;b_r<=cmd_b;
      prepared_r<=add_prepare(a_r,b_r);product_r<=mul_product(a_r,b_r);
      aligned_r<=add_shift(prepared_r);mul_norm_r<=mul_normalize(product_r);
      sum_r<=add_sum(aligned_r);mul_rounded_r<=mul_round(mul_norm_r);
      norm_r<=add_normalize(sum_r);mul_result_r<=mul_rounded_r;
      result_r<=multiply_r[4]?mul_result_r:add_round(norm_r);
      id_r[0]<=cmd_id;
      for(integer i=1;i<6;i=i+1) id_r[i]<=id_r[i-1];
    end
  end
endmodule
