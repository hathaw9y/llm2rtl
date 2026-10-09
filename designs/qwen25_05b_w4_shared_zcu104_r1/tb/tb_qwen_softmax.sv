`timescale 1ns/1ps
module tb_qwen_softmax;
 logic clk=0;always #2.5 clk=~clk;
 logic rst_n=0,cmd_valid,cmd_ready,rsp_valid,rsp_ready,rsp_error;
 logic [9:0] cmd_id,rsp_cmd_id;logic [4:0] cmd_src,cmd_dst,cmd_rows;
 logic [10:0] cmd_length,cmd_position;logic [7:0] rsp_error_code;
 logic src_rd_en,dst_wr_en;logic [12:0] src_rd_addr,dst_wr_addr;
 logic [127:0] src_rd_data,dst_wr_data;logic [15:0] dst_wr_mask;
 logic [127:0] src[0:4095],dst[0:2047],expected[0:2047],pipe[0:2];
 integer rows,length,position,count,cycles,writes,case_id,fd,got;string directory;
 qwen_softmax_executor dut(.*);
 always @* src_rd_data=pipe[2];
 always @(posedge clk) begin
  pipe[0]<=src_rd_en?src[src_rd_addr]:128'b0;
  for(integer i=1;i<3;i=i+1)pipe[i]<=pipe[i-1];
  if(src_rd_en && (src_rd_addr>=rows*256 || src_rd_addr%256>=((length+3)/4)))$fatal(1,"source bounds");
  if(dst_wr_en)begin
   if(dst_wr_addr>=count || dst_wr_mask!=16'hffff)$fatal(1,"destination bounds");
   dst[dst_wr_addr]<=dst_wr_data;writes=writes+1;
  end
 end
 task automatic run_command(input logic error_expected);
  writes=0;@(negedge clk);cmd_valid=1;@(posedge clk);if(!cmd_ready)$fatal(1,"not ready");
  @(negedge clk);cmd_valid=0;cycles=0;
  while(!rsp_valid)begin @(negedge clk);cycles=cycles+1;if(cycles>12000000)$fatal(1,"timeout");end
  if(rsp_error!=error_expected || rsp_cmd_id!=cmd_id)$fatal(1,"response case%0d error%0d",case_id,rsp_error_code);
  repeat(3)begin @(negedge clk);if(!rsp_valid || rsp_cmd_id!=cmd_id)$fatal(1,"response hold");end
  rsp_ready=1;@(negedge clk);rsp_ready=0;if(rsp_valid || !cmd_ready)$fatal(1,"completion");
 endtask
 initial begin
  if(!$value$plusargs("VECTORS=%s",directory))$fatal(1,"VECTORS required");
  cmd_valid=0;rsp_ready=0;cmd_id=0;cmd_src=18;cmd_dst=21;cmd_rows=1;cmd_length=1;cmd_position=0;rows=1;length=1;count=128;writes=0;case_id=0;
  repeat(4)@(negedge clk);rst_n=1;fd=$fopen({directory,"/headers.txt"},"r");if(fd==0)$fatal(1,"headers");
  while(!$feof(fd))begin
   got=$fscanf(fd,"%d %d %d\n",rows,length,position);if(got!=3)$fatal(1,"header invalid");
   cmd_rows=5'(rows);cmd_length=11'(length);cmd_position=11'(position);cmd_id=10'(case_id+1);count=rows*128;
   $readmemh($sformatf("%s/%0d_src.mem",directory,case_id),src,0,rows*256-1);
   $readmemh($sformatf("%s/%0d_expected.mem",directory,case_id),expected,0,count-1);
   run_command(0);
   for(integer i=0;i<count;i=i+1)if(dst[i]!==expected[i])$fatal(1,"Softmax payload case%0d word%0d got%h expected%h",case_id,i,dst[i],expected[i]);
   $display("PASS Softmax case%0d M%0d L%0d cycles%0d",case_id,rows,length,cycles);case_id=case_id+1;
  end
  $fclose(fd);cmd_rows=0;cmd_id=90;run_command(1);if(writes!=0)$fatal(1,"shape wrote");
  cmd_rows=1;cmd_length=1;cmd_position=0;rows=1;length=1;count=128;cmd_src=21;cmd_id=91;run_command(1);if(writes!=0)$fatal(1,"route wrote");cmd_src=18;
  src[0][31:0]=32'h7fc00000;cmd_id=92;run_command(1);
  src[0]=0;cmd_id=93;run_command(0);if(dst[0]!==128'h00000000000000000000000000003f80)$fatal(1,"error recovery");
  @(negedge clk);cmd_valid=1;@(negedge clk);cmd_valid=0;repeat(10)@(negedge clk);rst_n=0;repeat(3)@(negedge clk);rst_n=1;#1;
  if(rsp_valid || !cmd_ready)$fatal(1,"reset flush");cmd_id=94;run_command(0);
  $display("PASS Softmax payload/error/backpressure/reset");$finish;
 end
endmodule
