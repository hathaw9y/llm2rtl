module qwen_dot16x4 #(parameter integer OUTPUTS=4)(
  input logic clk,rst_n,input logic cmd_valid,output logic cmd_ready,
  input logic [9:0] cmd_id,input logic [511:0] cmd_a,input logic [OUTPUTS*16*32-1:0] cmd_b,
  output logic rsp_valid,input logic rsp_ready,output logic [9:0] rsp_cmd_id,
  output logic [OUTPUTS*32-1:0] rsp_data,output logic rsp_error
);
  logic busy_r,launch,leaf_ready;
  wire [OUTPUTS*16-1:0] ready_leaf;
  wire [0:4][0:OUTPUTS-1][0:15][31:0] data;
  wire [0:4][0:OUTPUTS-1][0:15] valid;
  wire [0:4][0:OUTPUTS-1][0:15][9:0] identity;
  wire [0:4][0:OUTPUTS-1][0:15] error;
  assign leaf_ready=&ready_leaf;assign cmd_ready=!busy_r && leaf_ready && rst_n;
  assign launch=cmd_valid && cmd_ready;
  wire [OUTPUTS-1:0] root_valid,root_error;
  assign rsp_valid=&root_valid;
  assign rsp_cmd_id=identity[4][0][0];
  assign rsp_error=|root_error;
  for(genvar n=0;n<OUTPUTS;n=n+1) begin:outputs_g
    assign rsp_data[n*32+:32]=data[4][n][0];
    assign root_valid[n]=valid[4][n][0];
    assign root_error[n]=error[4][n][0] || identity[4][n][0]!=identity[4][0][0];
    for(genvar k=0;k<16;k=k+1) begin:products_g
      qwen_fp32_pipe multiply(.clk,.rst_n,.cmd_valid(launch),.cmd_ready(ready_leaf[n*16+k]),.cmd_id,
        .cmd_multiply(1'b1),.cmd_a(cmd_a[k*32+:32]),.cmd_b(cmd_b[(n*16+k)*32+:32]),
        .rsp_valid(valid[0][n][k]),.rsp_ready(1'b1),.rsp_id(identity[0][n][k]),.rsp_data(data[0][n][k]),.rsp_error(error[0][n][k]));
    end
    for(genvar level=1;level<=4;level=level+1) begin:levels_g
      for(genvar i=0;i<(16>>level);i=i+1) begin:nodes_g
        wire unused_ready;
        wire node_ready;
        assign node_ready=level==4?rsp_ready:1'b1;
        wire node_valid=valid[level-1][n][i*2] && valid[level-1][n][i*2+1];
        qwen_fp32_pipe add(.clk,.rst_n,.cmd_valid(node_valid),.cmd_ready(unused_ready),
          .cmd_id(identity[level-1][n][i*2]),.cmd_multiply(1'b0),
          .cmd_a(data[level-1][n][i*2]),.cmd_b(data[level-1][n][i*2+1]),
          .rsp_valid(valid[level][n][i]),.rsp_ready(node_ready),
          .rsp_id(identity[level][n][i]),.rsp_data(data[level][n][i]),.rsp_error(error[level][n][i]));
      end
    end
  end
  always_ff @(posedge clk) begin
    if(!rst_n) busy_r<=0;
    else begin
      if(launch) busy_r<=1;
      if(rsp_valid && rsp_ready) busy_r<=0;
    end
  end
endmodule
