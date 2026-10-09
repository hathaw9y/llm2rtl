`timescale 1ns/1ps
module tb_qwen_rmsnorm;
  logic clk=0;always #2.5 clk=~clk;
  logic rst_n=0,cmd_valid,cmd_ready,rsp_valid,rsp_ready,rsp_error;
  logic [9:0] cmd_id,rsp_cmd_id;
  logic [4:0] cmd_src,cmd_param,cmd_dst,cmd_rows;
  logic [10:0] cmd_cols;logic [7:0] rsp_error_code;
  logic src_rd_en,param_rd_en,dst_wr_en;
  logic [12:0] src_rd_addr,param_rd_addr,dst_wr_addr;
  logic [127:0] src_rd_data,param_rd_data,dst_wr_data;
  logic [15:0] dst_wr_mask;
  logic [127:0] src[0:2047],param[0:111],dst[0:2047],expected[0:2047],ap[0:2],bp[0:2];
  integer count,rows,cycles,writes,case_id,fd,got;string directory;
  qwen_rmsnorm_executor dut(.*);
  always @* begin src_rd_data=ap[2];param_rd_data=bp[2];end
  always @(posedge clk) begin
    ap[0]<=src_rd_en?src[src_rd_addr]:128'b0;bp[0]<=param_rd_en?param[param_rd_addr]:128'b0;
    for(integer i=1;i<3;i=i+1) begin ap[i]<=ap[i-1];bp[i]<=bp[i-1];end
    if(src_rd_en && src_rd_addr>=count) $fatal(1,"source extent");
    if(param_rd_en && param_rd_addr>=112) $fatal(1,"gamma extent");
    if(dst_wr_en) begin
      if(dst_wr_addr>=count || dst_wr_mask!=16'hffff) $fatal(1,"destination extent/mask");
      dst[dst_wr_addr]<=dst_wr_data;writes=writes+1;
    end
  end
  task automatic run_command(input logic error_expected);
    writes=0;@(negedge clk);cmd_valid=1;@(posedge clk);if(!cmd_ready) $fatal(1,"not ready");
    @(negedge clk);cmd_valid=0;cycles=0;
    while(!rsp_valid) begin @(negedge clk);cycles=cycles+1;if(cycles>1000000) $fatal(1,"timeout");end
    if(rsp_error!=error_expected || rsp_cmd_id!=cmd_id) $fatal(1,"response case%0d code%0d",case_id,rsp_error_code);
    repeat(3) begin @(negedge clk);if(!rsp_valid || rsp_cmd_id!=cmd_id) $fatal(1,"response changed");end
    rsp_ready=1;@(negedge clk);rsp_ready=0;
    if(rsp_valid || !cmd_ready) $fatal(1,"completion count");
  endtask
  initial begin
    if(!$value$plusargs("VECTORS=%s",directory)) $fatal(1,"VECTORS required");
    cmd_valid=0;rsp_ready=0;cmd_id=0;cmd_src=0;cmd_param=22;cmd_dst=1;cmd_rows=1;cmd_cols=896;count=112;writes=0;case_id=0;
    repeat(4) @(negedge clk);rst_n=1;fd=$fopen({directory,"/headers.txt"},"r");
    if(fd==0) $fatal(1,"headers missing");
    while(!$feof(fd)) begin
      got=$fscanf(fd,"%d\n",rows);if(got!=1) $fatal(1,"headers invalid");
      cmd_rows=5'(rows);cmd_id=10'(case_id+1);count=rows*112;
      $readmemh($sformatf("%s/%0d_src.mem",directory,case_id),src,0,count-1);
      $readmemh($sformatf("%s/%0d_param.mem",directory,case_id),param,0,111);
      $readmemh($sformatf("%s/%0d_expected.mem",directory,case_id),expected,0,count-1);
      run_command(0);
      if(writes!=count) $fatal(1,"write count");
      for(integer i=0;i<count;i=i+1) if(dst[i]!==expected[i]) $fatal(1,"RMSNorm payload case%0d word%0d got=%h expected=%h",case_id,i,dst[i],expected[i]);
      $display("PASS RMSNorm case=%0d rows=%0d words=%0d",case_id,rows,writes);case_id=case_id+1;
    end
    $fclose(fd);cmd_id=90;cmd_rows=0;run_command(1);if(writes!=0) $fatal(1,"shape error wrote");
    cmd_rows=1;cmd_id=91;cmd_src=cmd_dst;run_command(1);if(writes!=0) $fatal(1,"alias error wrote");cmd_src=0;
    cmd_id=92;src[0][15:0]=16'h7fc0;run_command(1);if(writes!=0) $fatal(1,"nonfinite error wrote");
    $display("PASS RMSNorm payload/error/backpressure cases");$finish;
  end
endmodule
