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
  logic [4:0] valid_r;
  logic [3:0] multiply_r;
  logic [31:0] a_r,b_r,result_r,mul_result_r;
  logic [ID_WIDTH-1:0] id_r[0:4];
  add_align_t aligned_r;
  add_sum_t sum_r;
  add_norm_t norm_r;
  mul_product_t product_r;
  mul_norm_t mul_norm_r;
  logic advance;
  assign advance=!valid_r[4] || rsp_ready;
  assign cmd_ready=advance && rst_n;
  assign rsp_valid=valid_r[4];assign rsp_data=result_r;assign rsp_id=id_r[4];
  assign rsp_error=(result_r[30:23]==8'hff);
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      valid_r<='0;
      multiply_r<='0;a_r<='0;b_r<='0;result_r<='0;mul_result_r<='0;
      aligned_r<='0;sum_r<='0;norm_r<='0;product_r<='0;mul_norm_r<='0;
      for(integer i=0;i<5;i=i+1) id_r[i]<='0;
    end else if(advance) begin
      valid_r<={valid_r[3:0],cmd_valid};
      multiply_r<={multiply_r[2:0],cmd_multiply};
      // Stage clock enables preserve bubble/stall semantics and avoid idle math.
      if(cmd_valid) begin a_r<=cmd_a;b_r<=cmd_b;end
      if(valid_r[0]) begin aligned_r<=add_align(a_r,b_r);product_r<=mul_product(a_r,b_r);end
      if(valid_r[1]) begin sum_r<=add_sum(aligned_r);mul_norm_r<=mul_normalize(product_r);end
      if(valid_r[2]) begin norm_r<=add_normalize(sum_r);mul_result_r<=mul_round(mul_norm_r);end
      if(valid_r[3]) result_r<=multiply_r[3]?mul_result_r:add_round(norm_r);
      id_r[0]<=cmd_id;
      for(integer i=1;i<5;i=i+1) id_r[i]<=id_r[i-1];
    end
  end
endmodule
