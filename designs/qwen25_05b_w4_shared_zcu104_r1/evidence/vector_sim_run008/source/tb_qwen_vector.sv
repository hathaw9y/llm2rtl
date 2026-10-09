`timescale 1ns/1ps
module tb_qwen_vector;
  logic clk=0;always #2.5 clk=~clk;
  logic rst_n=0,cmd_valid,cmd_ready,rsp_valid,rsp_ready,rsp_error;
  logic [9:0] cmd_id,rsp_cmd_id;
  logic [4:0] cmd_src0,cmd_src1,cmd_dst,cmd_rows,cmd_dst_rows;
  logic [10:0] cmd_cols,cmd_src_rows,cmd_row;
  logic [12:0] cmd_src_cols,cmd_src1_cols,cmd_dst_cols,cmd_col;
  logic [2:0] cmd_mode;
  logic cmd_insert,cmd_begin;logic [7:0] rsp_error_code;
  logic src0_rd_en,src1_rd_en,dst_wr_en;
  logic [12:0] src0_rd_addr,src1_rd_addr,dst_wr_addr;
  logic [127:0] src0_rd_data,src1_rd_data,dst_wr_data;
  logic [15:0] dst_wr_mask;
  logic [127:0] src[0:2047],second[0:2047],dst[0:2047],expected[0:2047];
  logic [127:0] ap[0:2],bp[0:2];
  string directory;integer file_handle,got,case_id,cycles,words_a,words_b,words_dst,writes;
  integer mode,m,n,sm,sn,bn,dm,dn,row,col,ins,beg,a,b,d;
  qwen_vector_executor dut(.*);
  always @* begin src0_rd_data=ap[2];src1_rd_data=bp[2];end
  always @(posedge clk) begin
    if($test$plusargs("DEBUG") && case_id==0 && dut.col_r==0) $display("t=%0t state=%0d en=%b addr=%0d ap2=%h aport=%h lane=%d enB=%b bp=%h/%h/%h bport=%h",$time,dut.state_r,src0_rd_en,src0_rd_addr,ap[2],src0_rd_data,dut.source_w4_lane,src1_rd_en,bp[0],bp[1],bp[2],src1_rd_data);
    ap[0]<=src0_rd_en?src[src0_rd_addr]:128'b0;bp[0]<=src1_rd_en?second[src1_rd_addr]:128'b0;
    for(integer i=1;i<3;i=i+1) begin ap[i]<=ap[i-1];bp[i]<=bp[i-1];end
    if(src0_rd_en && src0_rd_addr>=words_a) $fatal(1,"source extent");
    if(src1_rd_en && src1_rd_addr>=words_b) $fatal(1,"second source extent");
    if(dst_wr_en) begin
      if(dst_wr_addr>=words_dst || dst_wr_mask!=16'hffff) $fatal(1,"destination extent/mask");
      dst[dst_wr_addr]<=dst_wr_data;writes=writes+1;
    end
  end
  task automatic error_case(input logic [7:0] code);
    writes=0;
    @(negedge clk);cmd_valid=1;@(posedge clk);if(!cmd_ready) $fatal(1,"error test not ready");
    @(negedge clk);cmd_valid=0;cycles=0;
    while(!rsp_valid) begin @(negedge clk);cycles=cycles+1;if(cycles>500) $fatal(1,"error response timeout");end
    if(!rsp_error || rsp_error_code!=code || rsp_cmd_id!=cmd_id || writes!=0) $fatal(1,"error contract");
    repeat(3) @(negedge clk);rsp_ready=1;@(negedge clk);rsp_ready=0;
  endtask
  initial begin
    if(!$value$plusargs("VECTORS=%s",directory)) $fatal(1,"VECTORS required");
    file_handle=$fopen({directory,"/headers.txt"},"r");if(file_handle==0) $fatal(1,"headers");
    cmd_valid=0;rsp_ready=0;cmd_id=0;cmd_src0=0;cmd_src1=1;cmd_dst=3;cmd_rows=1;cmd_dst_rows=1;
    cmd_cols=8;cmd_src_rows=1;cmd_src_cols=8;cmd_src1_cols=8;cmd_dst_cols=8;cmd_row=0;cmd_col=0;cmd_mode=1;cmd_insert=0;cmd_begin=0;
    words_a=1;words_b=1;words_dst=1;writes=0;
    repeat(4) @(negedge clk);rst_n=1;case_id=0;
    while(!$feof(file_handle)) begin
      got=$fscanf(file_handle,"%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",mode,m,n,sm,sn,bn,dm,dn,row,col,ins,beg,a,b,d,words_a,words_b,words_dst);
      if(got!=18) $fatal(1,"case header");
      $readmemh($sformatf("%s/%0d_src.mem",directory,case_id),src,0,words_a-1);
      $readmemh($sformatf("%s/%0d_second.mem",directory,case_id),second,0,words_b-1);
      $readmemh($sformatf("%s/%0d_initial.mem",directory,case_id),dst,0,words_dst-1);
      $readmemh($sformatf("%s/%0d_expected.mem",directory,case_id),expected,0,words_dst-1);
      cmd_id=10'(case_id);cmd_mode=3'(mode);cmd_rows=5'(m);cmd_cols=11'(n);cmd_src_rows=11'(sm);cmd_src_cols=13'(sn);cmd_src1_cols=13'(bn);
      cmd_dst_rows=5'(dm);cmd_dst_cols=13'(dn);cmd_row=11'(row);cmd_col=13'(col);cmd_insert=ins!=0;cmd_begin=beg!=0;
      cmd_src0=5'(a);cmd_src1=5'(b);cmd_dst=5'(d);writes=0;
      @(negedge clk);cmd_valid=1;@(posedge clk);if(!cmd_ready) $fatal(1,"not ready");
      @(negedge clk);cmd_valid=0;cycles=0;
      while(!rsp_valid) begin @(negedge clk);cycles=cycles+1;if(cycles>1000000) $fatal(1,"timeout case %0d",case_id);end
      if(rsp_error || rsp_cmd_id!=cmd_id) $fatal(1,"response case%0d code%0d x=%h y=%h row=%0d col=%0d a_addr=%0d b_addr=%0d",case_id,rsp_error_code,dut.x_r,dut.y_r,dut.row_r,dut.col_r,src0_rd_addr,src1_rd_addr);
      for(integer i=0;i<words_dst;i=i+1) if(dst[i]!==expected[i]) $fatal(1,"payload case%0d mode%0d word%0d got=%h expected=%h",case_id,mode,i,dst[i],expected[i]);
      repeat(3) begin @(negedge clk);if(!rsp_valid || rsp_cmd_id!=cmd_id) $fatal(1,"unstable response");end
      rsp_ready=1;@(negedge clk);rsp_ready=0;
      if(rsp_valid || !cmd_ready) $fatal(1,"completion count");
      $display("PASS vector case=%0d mode=%0d M=%0d N=%0d writes=%0d",case_id,mode,m,n,writes);case_id=case_id+1;
    end
    $fclose(file_handle);
    cmd_id=90;cmd_src0=cmd_dst;error_case(8'h02);
    cmd_id=91;cmd_src0=19;cmd_rows=0;error_case(8'h01);
    cmd_id=92;cmd_mode=4;cmd_rows=1;cmd_cols=8;cmd_src_rows=1;cmd_src_cols=8;cmd_dst_rows=1;cmd_dst_cols=8;
    cmd_src0=11;cmd_src1=0;cmd_dst=19;cmd_insert=0;cmd_begin=0;cmd_row=0;cmd_col=0;words_a=2;words_b=1;words_dst=1;
    src[0]=0;src[0][31:0]=32'h7fc00000;error_case(8'h05);
    cmd_id=93;cmd_mode=3;cmd_cols=128;cmd_src_cols=128;cmd_src1_cols=1;cmd_dst_cols=128;cmd_src0=7;cmd_src1=8;cmd_dst=19;
    words_a=4;words_b=1;words_dst=16;src[0]=0;src[0][3:0]=8;second[0]=0;second[0][31:0]=32'h3f800000;error_case(8'h04);
    // Cancel work mid-command, then prove another complete CAST succeeds.
    cmd_id=94;cmd_mode=4;cmd_cols=8;cmd_src_cols=8;cmd_dst_cols=8;cmd_src0=11;cmd_src1=0;cmd_dst=19;
    words_a=2;words_dst=1;src[0]={4{32'h3f800000}};src[1]=src[0];writes=0;
    @(negedge clk);cmd_valid=1;@(negedge clk);cmd_valid=0;repeat(6) @(negedge clk);
    rst_n=0;repeat(3) @(negedge clk);rst_n=1;repeat(5) @(negedge clk);
    if(rsp_valid || !cmd_ready) $fatal(1,"reset recovery");
    cmd_id=95;cmd_valid=1;@(negedge clk);cmd_valid=0;
    // The producer may replace metadata immediately after acceptance, while
    // CHECK_COMMAND validates the saved request on the next rising edge.
    cmd_rows=0;cmd_cols=0;cmd_src_rows=0;cmd_src_cols=0;cmd_src1_cols=0;
    cmd_dst_rows=0;cmd_dst_cols=0;cmd_src0=31;cmd_src1=31;cmd_dst=31;cmd_mode=7;
    cycles=0;while(!rsp_valid) begin @(negedge clk);cycles=cycles+1;if(cycles>1000) $fatal(1,"reset recovery computation timeout");end
    if(rsp_error || rsp_cmd_id!=95 || dst[0]!=={8{16'h3f80}}) $fatal(1,"reset recovery payload");
    rsp_ready=1;@(negedge clk);rsp_ready=0;
    $display("PASS vector all%0d payload/selector/backpressure cases, saved metadata after acceptance",case_id);$finish;
  end
endmodule
