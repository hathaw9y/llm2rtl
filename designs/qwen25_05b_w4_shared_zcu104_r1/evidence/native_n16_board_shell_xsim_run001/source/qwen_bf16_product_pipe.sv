// Native BF16 x signed INT4 (W4) or BF16 x BF16 product. Six elastic
// stages match the former leaf latency. Output is exact FP32, with FTZ
// inputs/outputs and overflow/error behavior matching the numeric contract.
// W4 uses only the lower four bits of cmd_b; -8 is reserved/invalid.
module qwen_bf16_product_pipe #(
  parameter integer ID_WIDTH=10
)(
  input logic clk,rst_n,cmd_valid,output logic cmd_ready,
  input logic [ID_WIDTH-1:0] cmd_id,
  input logic cmd_w4,input logic [15:0] cmd_a,cmd_b,
  output logic rsp_valid,input logic rsp_ready,
  output logic [ID_WIDTH-1:0] rsp_id,output logic [31:0] rsp_data,
  output logic rsp_error
);
  logic [5:0] valid_r;
  logic [ID_WIDTH-1:0] id_r[0:5];
  logic [7:0] a_sig_r,b_sig_r;
  logic [3:0] magnitude;
  (* use_dsp = "yes" *) logic [15:0] product_r;
  logic [15:0] product_s3;
  logic [3:0] leading_s3;
  logic signed [10:0] exponent_s1,exponent_s2,exponent_s3,exponent_s4;
  logic [3:0] origin_s1,origin_s2,origin_s3;
  logic [3:0] sign_r,zero_r,invalid_r;
  logic [31:0] significand_s4,result_s5,result_s6;
  wire advance=!valid_r[5] || rsp_ready;
  assign cmd_ready=advance && rst_n;
  assign rsp_valid=valid_r[5];assign rsp_id=id_r[5];
  assign rsp_data=result_s6;assign rsp_error=result_s6[30:23]==255;
  assign magnitude=cmd_b[3]?(4'b0-cmd_b[3:0]):cmd_b[3:0];
  function automatic logic [3:0] top_bit(input logic [15:0] x);
    logic [3:0] bit_index;
    bit_index=0;
    for(integer i=0;i<16;i=i+1)if(x[i])bit_index=4'(i);
    return bit_index;
  endfunction
  always_ff @(posedge clk) begin
    if(!rst_n)begin
      valid_r<=0;sign_r<=0;zero_r<=0;invalid_r<=0;
      a_sig_r<=0;b_sig_r<=0;product_r<=0;product_s3<=0;leading_s3<=0;
      exponent_s1<=0;exponent_s2<=0;exponent_s3<=0;exponent_s4<=0;
      origin_s1<=0;origin_s2<=0;origin_s3<=0;
      significand_s4<=0;result_s5<=0;result_s6<=0;
      for(integer i=0;i<6;i=i+1)id_r[i]<=0;
    end else if(advance)begin
      valid_r<={valid_r[4:0],cmd_valid};id_r[0]<=cmd_id;
      for(integer i=1;i<6;i=i+1)id_r[i]<=id_r[i-1];
      sign_r<={sign_r[2:0],cmd_a[15]^(cmd_w4?cmd_b[3]:cmd_b[15])};
      zero_r<={zero_r[2:0],cmd_a[14:7]==0 || (cmd_w4?cmd_b[3:0]==0:cmd_b[14:7]==0)};
      invalid_r<={invalid_r[2:0],cmd_a[14:7]==255 || (cmd_w4?cmd_b[3:0]==8:cmd_b[14:7]==255)};
      // One shared8x8 unsigned DSP multiplier: W4's second significand is
      // the zero-extended3-bit magnitude. No INT4-to-FP32 conversion.
      a_sig_r<={1'b1,cmd_a[6:0]};
      b_sig_r<=cmd_w4?{4'b0,magnitude}:{1'b1,cmd_b[6:0]};
      exponent_s1<=cmd_w4?$signed({3'b0,cmd_a[14:7]}):
        $signed({3'b0,cmd_a[14:7]})+$signed({3'b0,cmd_b[14:7]})-11'sd127;
      origin_s1<=cmd_w4?4'd7:4'd14;
      product_r<=a_sig_r*b_sig_r;exponent_s2<=exponent_s1;origin_s2<=origin_s1;
      product_s3<=product_r;leading_s3<=top_bit(product_r);
      exponent_s3<=exponent_s2;origin_s3<=origin_s2;
      significand_s4<={16'b0,product_s3}<<(5'd23-{1'b0,leading_s3});
      exponent_s4<=exponent_s3+$signed({7'b0,leading_s3})-$signed({7'b0,origin_s3});
      // Product precision is at most16bits (11bits for W4), so normal
      // FP32 products are exact: no rounding bits can be discarded.
      if(invalid_r[3])result_s5<=32'h7fc00000;
      else if(zero_r[3] || exponent_s4<=0)result_s5<={sign_r[3],31'b0};
      else if(exponent_s4>=255)result_s5<={sign_r[3],8'hff,23'b0};
      else result_s5<={sign_r[3],exponent_s4[7:0],significand_s4[22:0]};
      result_s6<=result_s5;
    end
  end
endmodule
