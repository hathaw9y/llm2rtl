`timescale 1ns/1ps
module tb_qwen_rope;
  logic clk=0;always #5 clk=~clk;
  logic rst_n=0,cmd_valid,cmd_ready,rsp_valid,rsp_ready,rsp_error;
  logic [9:0] cmd_id,rsp_cmd_id;
  logic [4:0] cmd_src,cmd_param,cmd_dst,cmd_rows;
  logic [3:0] cmd_heads;logic [7:0] rsp_error_code;
  logic src_rd_en,param_rd_en,dst_wr_en;
  logic [12:0] src_rd_addr,param_rd_addr,dst_wr_addr;
  logic [127:0] src_rd_data,param_rd_data,dst_wr_data;
  logic [15:0] dst_wr_mask;
  logic [127:0] src[0:2047],param[0:255],dst[0:2047],expected[0:2047];
  logic [127:0] src_pipe[0:2],param_pipe[0:2];
  integer writes,cycles,word_count;
  string vector_dir;
  qwen_rope_executor dut(.*);
  assign src_rd_data=src_pipe[2];assign param_rd_data=param_pipe[2];
  always @(posedge clk) begin
    src_pipe[0]<=src_rd_en?src[src_rd_addr]:128'b0;
    param_pipe[0]<=param_rd_en?param[param_rd_addr]:128'b0;
    for(integer i=1;i<3;i=i+1) begin src_pipe[i]<=src_pipe[i-1];param_pipe[i]<=param_pipe[i-1];end
    if(dst_wr_en) begin
      if(dst_wr_addr>=word_count || dst_wr_mask!=16'hffff) $fatal(1,"write extent/mask");
      dst[dst_wr_addr]<=dst_wr_data;writes=writes+1;
    end
  end
  task automatic publish;
    @(negedge clk);cmd_valid=1;
    @(posedge clk);if(!cmd_ready) $fatal(1,"executor not ready");
    @(negedge clk);cmd_valid=0;
  endtask
  task automatic wait_response(input logic expect_error);
    cycles=0;
    while(!rsp_valid) begin
      @(negedge clk);cycles=cycles+1;
      if(cycles>1000000) $fatal(1,"timeout");
      if(cmd_ready) $fatal(1,"early ready");
    end
    if(rsp_cmd_id!=cmd_id || rsp_error!=expect_error) $fatal(1,"response identity/error");
    repeat(5) begin
      @(negedge clk);
      if(!rsp_valid || rsp_cmd_id!=cmd_id || rsp_error!=expect_error) $fatal(1,"response under backpressure");
    end
    rsp_ready=1;@(negedge clk);rsp_ready=0;
    if(rsp_valid || !cmd_ready) $fatal(1,"completion count/ready");
  endtask
  initial begin
    if(!$value$plusargs("VECTORS=%s",vector_dir)) $fatal(1,"VECTORS required");
    cmd_valid=0;rsp_ready=0;cmd_id=0;cmd_src=0;cmd_param=22;cmd_dst=3;cmd_rows=0;cmd_heads=0;writes=0;word_count=2048;
    repeat(4) @(negedge clk);rst_n=1;
    for(integer test_case=0;test_case<4;test_case=test_case+1) begin
      cmd_rows=test_case<2?1:16;cmd_heads=(test_case%2)==0?2:14;cmd_id=10'(test_case+17);
      word_count=int'(cmd_rows)*int'(cmd_heads)*8;
      $readmemh($sformatf("%s/%0d_src.mem",vector_dir,test_case),src,0,word_count-1);
      $readmemh($sformatf("%s/%0d_param.mem",vector_dir,test_case),param,0,int'(cmd_rows)*16-1);
      $readmemh($sformatf("%s/%0d_expected.mem",vector_dir,test_case),expected,0,word_count-1);
      for(integer i=0;i<2048;i=i+1) dst[i]='0;
      writes=0;publish();wait_response(0);
      if(writes!=word_count) $fatal(1,"write count %0d expected %0d",writes,word_count);
      for(integer i=0;i<word_count;i=i+1) if(dst[i]!==expected[i]) $fatal(1,"payload case=%0d word=%0d got=%h expected=%h",test_case,i,dst[i],expected[i]);
      $display("PASS RoPE case=%0d rows=%0d heads=%0d words=%0d",test_case,cmd_rows,cmd_heads,writes);
    end
    writes=0;cmd_rows=0;cmd_id=91;publish();wait_response(1);
    if(writes!=0) $fatal(1,"invalid command wrote data");
    cmd_rows=1;cmd_src=cmd_dst;cmd_id=92;publish();wait_response(1);cmd_src=0;
    src[0][15:0]=16'h7fc0;cmd_id=93;publish();wait_response(1);
    // Reset during an accepted command, then require clean recovery.
    src[0][15:0]=16'h3f80;cmd_id=94;publish();repeat(6) @(negedge clk);
    rst_n=0;repeat(3) @(negedge clk);rst_n=1;repeat(5) @(negedge clk);
    if(rsp_valid || !cmd_ready) $fatal(1,"reset recovery");
    $display("PASS RoPE shape/alias/nonfinite errors, response backpressure, reset");
    $finish;
  end
endmodule
