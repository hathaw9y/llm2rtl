`timescale 1ns/1ps
module tb_qwen_gemm;
 logic clk=0;always #2.5 clk=~clk;
 logic rst_n=0,cmd_valid,cmd_ready,rsp_valid,rsp_ready,rsp_error;
 logic [9:0] cmd_id,rsp_cmd_id;logic [4:0] cmd_a,cmd_b,cmd_scale,cmd_dst,cmd_rows;
 logic [10:0] cmd_n,cmd_k;logic [1:0] cmd_mode;logic cmd_init;logic [7:0] rsp_error_code;
 logic act_rd_en,wgt_rd_en,scale_rd_en,dst_rd_en,dst_wr_en;
 logic [12:0] act_rd_addr,wgt_rd_addr,scale_rd_addr,dst_rd_addr,dst_wr_addr;
 logic [127:0] act_rd_data,wgt_rd_data,scale_rd_data,dst_rd_data,dst_wr_data;logic [15:0] dst_wr_mask;
 logic [127:0] act[0:2047],wgt[0:8191],scale[0:31],dst[0:4095],expected[0:4095];
 logic [127:0] ap[0:2],bp[0:2],sp[0:2],dp[0:2];
 integer act_reads,wgt_reads;
 integer mode,rows,n,k,initialize,ac,bc,sc,dc,cycles,writes,case_id,fd,got;string directory;
 qwen_gemm_executor dut(.*);
 always @* begin act_rd_data=ap[2];wgt_rd_data=bp[2];scale_rd_data=sp[2];dst_rd_data=dp[2];end
 always @(posedge clk)begin
  ap[0]<=act_rd_en?act[act_rd_addr]:128'b0;bp[0]<=wgt_rd_en?wgt[wgt_rd_addr]:128'b0;sp[0]<=scale_rd_en?scale[scale_rd_addr]:128'b0;dp[0]<=dst_rd_en?dst[dst_rd_addr]:128'b0;
  for(integer i=1;i<3;i=i+1)begin ap[i]<=ap[i-1];bp[i]<=bp[i-1];sp[i]<=sp[i-1];dp[i]<=dp[i-1];end
  if(act_rd_en)act_reads=act_reads+1;
  if(wgt_rd_en)wgt_reads=wgt_reads+1;
  if(act_rd_en && act_rd_addr>=ac)$fatal(1,"ACT bounds");
  if(wgt_rd_en && wgt_rd_addr>=bc)$fatal(1,"WGT bounds");
  if(scale_rd_en && scale_rd_addr>=sc)$fatal(1,"SCALE bounds");
  if(dst_rd_en && dst_rd_addr>=dc)$fatal(1,"PSUM bounds");
  if(dst_wr_en)begin if(dst_wr_addr>=dc || dst_wr_mask!=16'hffff)$fatal(1,"DST bounds");dst[dst_wr_addr]<=dst_wr_data;writes=writes+1;end
 end
 task automatic run_command(input logic error_expected);
  writes=0;act_reads=0;wgt_reads=0;@(negedge clk);cmd_valid=1;@(posedge clk);if(!cmd_ready)$fatal(1,"not ready");@(negedge clk);cmd_valid=0;cycles=0;
  while(!rsp_valid)begin @(negedge clk);cycles=cycles+1;if(cycles>1000000)$fatal(1,"timeout case%0d state%0d",case_id,dut.state_r);end
  if(rsp_error!=error_expected || rsp_cmd_id!=cmd_id)$fatal(1,"response case%0d code%0d",case_id,rsp_error_code);
  repeat(3)begin @(negedge clk);if(!rsp_valid || rsp_cmd_id!=cmd_id)$fatal(1,"response hold");end
  rsp_ready=1;@(negedge clk);rsp_ready=0;if(rsp_valid || !cmd_ready)$fatal(1,"completion");
 endtask
 initial begin
  if(!$value$plusargs("VECTORS=%s",directory))$fatal(1,"vectors");
  cmd_valid=0;rsp_ready=0;cmd_id=0;cmd_a=6;cmd_b=7;cmd_scale=8;cmd_dst=11;cmd_rows=1;cmd_n=128;cmd_k=128;cmd_mode=0;cmd_init=1;ac=16;bc=512;sc=32;dc=32;writes=0;case_id=0;
  repeat(4)@(negedge clk);rst_n=1;fd=$fopen({directory,"/headers.txt"},"r");if(fd==0)$fatal(1,"headers");
  while(!$feof(fd))begin
   got=$fscanf(fd,"%d %d %d %d %d %d %d %d %d\n",mode,rows,n,k,initialize,ac,bc,sc,dc);if(got!=9)$fatal(1,"header invalid");
   cmd_mode=2'(mode);cmd_rows=5'(rows);cmd_n=11'(n);cmd_k=11'(k);cmd_init=1'(initialize);cmd_a=mode==2?21:6;cmd_b=mode==0?7:mode==1?9:10;cmd_dst=mode==1?18:11;cmd_id=10'(case_id+1);
   $readmemh($sformatf("%s/%0d_act.mem",directory,case_id),act,0,ac-1);
   $readmemh($sformatf("%s/%0d_wgt.mem",directory,case_id),wgt,0,bc-1);
   $readmemh($sformatf("%s/%0d_scale.mem",directory,case_id),scale,0,sc-1);
   $readmemh($sformatf("%s/%0d_initial.mem",directory,case_id),dst,0,dc-1);
   $readmemh($sformatf("%s/%0d_expected.mem",directory,case_id),expected,0,dc-1);
   run_command(0);
   for(integer i=0;i<dc;i=i+1)if(dst[i]!==expected[i])$fatal(1,"GEMM case%0d word%0d got=%h expected=%h",case_id,i,dst[i],expected[i]);
   if(mode==0 && (act_reads!=rows*16 || wgt_reads!=rows*512))$fatal(1,"W4 supply read counts ACT%0d WGT%0d",act_reads,wgt_reads);
   $display("PASS GEMM case%0d mode%0d M%0d N%0d K%0d cycles%0d ACT_reads%0d WGT_reads%0d",case_id,mode,rows,n,k,cycles,act_reads,wgt_reads);case_id=case_id+1;
  end
  $fclose(fd);
  // Reuse independent QK N17 golden prefixes to check partial second,
  // third and fourth native output words in the new N16 group.
  for(integer tail_n=5;tail_n<=13;tail_n=tail_n+4)begin
   cmd_mode=1;cmd_rows=16;cmd_n=11'(tail_n);cmd_k=64;cmd_init=1;
   cmd_a=6;cmd_b=9;cmd_dst=18;cmd_id=10'(120+tail_n);
   ac=128;bc=tail_n*8;sc=32;dc=4096;
   $readmemh({directory,"/6_act.mem"},act,0,127);
   $readmemh({directory,"/6_wgt.mem"},wgt,0,135);
   $readmemh({directory,"/6_initial.mem"},dst,0,4095);
   $readmemh({directory,"/6_expected.mem"},expected,0,4095);
   for(integer r=0;r<16;r=r+1)
    for(integer c=tail_n;c<1024;c=c+1)expected[r*256+c/4][(c%4)*32+:32]=0;
   run_command(0);
   for(integer i=0;i<4096;i=i+1)if(dst[i]!==expected[i])$fatal(1,"N16 QK tail%0d word%0d",tail_n,i);
   $display("PASS GEMM N16 QK tail N%0d padded row exact",tail_n);
  end
  // A nonfinite value in the second PV word must produce an identified
  // error before result writes. INIT's destination clear is intentional.
  cmd_mode=2;cmd_rows=1;cmd_n=64;cmd_k=2;cmd_init=1;
  cmd_a=21;cmd_b=10;cmd_dst=11;cmd_id=140;ac=128;bc=16;dc=16;
  for(integer i=0;i<128;i=i+1)act[i]=0;
  for(integer i=0;i<16;i=i+1)wgt[i]=0;
  wgt[1][15:0]=16'h7fc0;run_command(1);
  if(writes!=16 || rsp_error_code!=8'h03)$fatal(1,"N16 PV upper-word error");wgt[1]=0;
  $display("PASS GEMM N16 PV upper-word nonfinite");
  cmd_rows=0;cmd_id=90;run_command(1);if(writes!=0)$fatal(1,"shape wrote");
  cmd_mode=0;cmd_rows=1;cmd_n=128;cmd_k=128;cmd_a=6;cmd_b=7;cmd_dst=11;cmd_init=1;ac=16;bc=512;sc=32;dc=32;
  cmd_a=7;cmd_id=91;run_command(1);if(writes!=0)$fatal(1,"route wrote");cmd_a=6;
  for(integer i=0;i<16;i=i+1)act[i]=0;act[0][15:0]=16'h7fc0;cmd_id=92;run_command(1);act[0]=0;
  for(integer i=0;i<512;i=i+1)wgt[i]=0;wgt[0][3:0]=8;cmd_id=93;run_command(1);wgt[0]=0;
  for(integer i=0;i<32;i=i+1)scale[i]={4{32'h3f800000}};scale[0][31:0]=32'hbf800000;cmd_id=94;run_command(1);scale[0]={4{32'h3f800000}};
  cmd_init=0;dst[0][31:0]=32'h7fc00000;cmd_id=95;run_command(1);dst[0]=0;
  cmd_init=1;cmd_id=96;run_command(0);
  @(negedge clk);cmd_valid=1;@(negedge clk);cmd_valid=0;repeat(15)@(negedge clk);rst_n=0;repeat(3)@(negedge clk);rst_n=1;#1;
  if(rsp_valid || !cmd_ready)$fatal(1,"reset flush");cmd_id=97;run_command(0);
  // Reset in a partly returned weight burst, then refill and replay. Cached
  // data from the aborted command must never bypass the new request pipeline.
  @(negedge clk);cmd_valid=1;@(negedge clk);cmd_valid=0;
  wait(dut.state_r==dut.BURST_WGT && dut.wgt_issued_r==2);
  @(negedge clk);rst_n=0;repeat(3)@(negedge clk);rst_n=1;
  cmd_id=98;run_command(0);
  if(act_reads!=16 || wgt_reads!=512)$fatal(1,"post-reset burst refill count");
  $display("PASS GEMM supply cache/burst reset refill");
  // The upper N16 outputs occupy the fourth native128 word. Exercise
  // faults there as well as the original lower half before any result write.
  // ACCUM avoids INIT's intentional pre-compute destination clear writes.
  cmd_init=0;wgt[48][3:0]=8;cmd_id=99;run_command(1);
  if(writes!=0)$fatal(1,"upper W4 fault wrote");wgt[48]=0;
  scale[3][31:0]=32'hbf800000;cmd_id=100;run_command(1);
  if(writes!=0)$fatal(1,"upper scale fault wrote");scale[3]={4{32'h3f800000}};
  cmd_init=0;dst[3][31:0]=32'h7fc00000;cmd_id=101;run_command(1);
  if(writes!=0)$fatal(1,"upper previous fault wrote");dst[3]=0;cmd_init=1;
  // Abort after the newly added upper weight lanes have been issued.
  @(negedge clk);cmd_valid=1;@(negedge clk);cmd_valid=0;
  wait(dut.state_r==dut.BURST_WGT && dut.wgt_issued_r==14);
  @(negedge clk);rst_n=0;repeat(3)@(negedge clk);rst_n=1;
  cmd_id=102;run_command(0);
  if(act_reads!=16 || wgt_reads!=512)$fatal(1,"upper burst reset refill count");
  $display("PASS GEMM N16 upper-half faults/reset refill");
  $display("PASS GEMM payload/error/backpressure/reset");$finish;
 end
endmodule
