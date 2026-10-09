`timescale 1ns/1ps
module tb_qwen_nonlinear;
  localparam integer COUNT=6151;
  logic clk=0;always #2.5 clk=~clk;
  logic rst_n=0,cmd_valid,cmd_ready,rsp_valid,rsp_ready,rsp_error;
  logic [9:0] cmd_id,rsp_cmd_id;
  logic [1:0] cmd_mode;
  logic [31:0] cmd_x,rsp_data;
  logic [66:0] vectors[0:COUNT-1];
  string vector_file;
  integer cycles;
  qwen_nonlinear_scalar dut(.*);
  initial begin
    if(!$value$plusargs("VECTORS=%s",vector_file)) $fatal(1,"VECTORS file required");
    $readmemh(vector_file,vectors);
    cmd_valid=0;rsp_ready=0;cmd_id=0;cmd_mode=0;cmd_x=0;
    repeat(4) @(negedge clk);rst_n=1;
    for(integer i=0;i<COUNT;i=i+1) begin
      @(negedge clk);cmd_id=10'(i);cmd_mode=vectors[i][66:65];cmd_x=vectors[i][64:33];cmd_valid=1;
      @(posedge clk);if(!cmd_ready) $fatal(1,"not ready");
      @(negedge clk);cmd_valid=0;cycles=0;
      while(!rsp_valid) begin @(negedge clk);cycles=cycles+1;if(cycles>300) $fatal(1,"timeout vector=%0d mode=%0d x=%h state=%0d step=%0d fp_valid=%b",i,cmd_mode,cmd_x,dut.state_r,dut.step_r,dut.fp_rsp_valid);end
      if(rsp_cmd_id!=10'(i) || rsp_error!=vectors[i][0]) $fatal(1,"identity/error vector%0d",i);
      if(!rsp_error && rsp_data!==vectors[i][32:1]) $fatal(1,"nonlinear vector%0d mode%0d x=%h got=%h expected=%h",i,cmd_mode,cmd_x,rsp_data,vectors[i][32:1]);
      repeat(3) begin
        @(negedge clk);
        if(!rsp_valid || rsp_cmd_id!=10'(i) || (!rsp_error && rsp_data!==vectors[i][32:1])) $fatal(1,"unstable response");
      end
      rsp_ready=1;@(negedge clk);rsp_ready=0;
      if(rsp_valid) $fatal(1,"extra response");
    end
    $display("PASS nonlinear bit-exact exp/reciprocal/rsqrt %0d, errors/backpressure",COUNT);$finish;
  end
endmodule
