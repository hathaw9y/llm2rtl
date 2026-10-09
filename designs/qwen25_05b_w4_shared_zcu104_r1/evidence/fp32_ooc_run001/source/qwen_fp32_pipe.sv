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
  logic [2:0] valid_r;
  logic [31:0] data_r[0:2];
  logic [ID_WIDTH-1:0] id_r[0:2];
  logic advance;
  assign advance=!valid_r[2] || rsp_ready;
  assign cmd_ready=advance && rst_n;
  assign rsp_valid=valid_r[2];assign rsp_data=data_r[2];assign rsp_id=id_r[2];
  assign rsp_error=(data_r[2][30:23]==8'hff);
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      valid_r<='0;
      for(integer i=0;i<3;i=i+1) begin data_r[i]<='0;id_r[i]<='0;end
    end else if(advance) begin
      valid_r<={valid_r[1:0],cmd_valid};
      data_r[0]<=cmd_multiply?fp_mul(cmd_a,cmd_b):fp_add(cmd_a,cmd_b);
      id_r[0]<=cmd_id;
      for(integer i=1;i<3;i=i+1) begin data_r[i]<=data_r[i-1];id_r[i]<=id_r[i-1];end
    end
  end
endmodule
