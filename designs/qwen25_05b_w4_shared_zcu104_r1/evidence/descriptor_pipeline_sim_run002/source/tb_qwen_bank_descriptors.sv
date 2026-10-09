`timescale 1ns/1ps
module tb_qwen_bank_descriptors;
 logic clk=0;always #2.5 clk=~clk;
 logic rst_n=0;logic [22:0] bank_busy,valid,partial,assembling,attention_layout;
 logic [255:0] command;logic issue_valid,command_legal,bank_eligible,validation_ready;
 logic [6:0] commit_valid,commit_error;logic [6:0][255:0] commit_command;
 logic [22:0][1:0] format;logic [22:0][10:0] rows;logic [22:0][12:0] cols,covered_columns;
 logic [22:0][15:0] tensor;logic [22:0][5:0] next_group;logic [22:0][17:0] covered_bytes;
 logic [255:0] program_words[0:17];
 qwen_bank_descriptors dut(.*);
 task automatic settle;
  repeat(4)@(negedge clk);#1;
  if(!validation_ready)$fatal(1,"validation did not settle");
 endtask
 task automatic run(input integer i,input logic error);
  @(negedge clk);command=program_words[i];#1;
  if(validation_ready || bank_eligible || !command_legal)$fatal(1,"new command reused stale validation");
  settle();
  if(!command_legal || !bank_eligible)$fatal(1,"illegal fixture%0d",i);
  issue_valid=1;@(negedge clk);issue_valid=0;#1;
  if(validation_ready || bank_eligible)$fatal(1,"issue did not flush validation");
  // Completion may be delayed arbitrarily; no successful commit before response.
  repeat(3)@(negedge clk);commit_command[0]=command;commit_error[0]=error;commit_valid[0]=1;
  @(negedge clk);commit_valid=0;commit_error=0;#1;
  if(validation_ready || bank_eligible)$fatal(1,"completion did not flush validation");
 endtask
 initial begin
  bank_busy=0;command=0;issue_valid=0;commit_valid=0;commit_error=0;commit_command=0;
  $readmemh("designs/qwen25_05b_w4_shared_zcu104_r1/evidence/descriptor_run001/commands.mem",program_words);
  repeat(4)@(negedge clk);rst_n=1;
  for(integer i=0;i<4;i=i+1)run(i,0);
  if(!valid[11] || !partial[11] || next_group[11]!=1 || valid[6] || valid[7] || valid[8])$fatal(1,"partial/last-use commit");
  for(integer i=4;i<7;i=i+1)run(i,0);
  // Wrong group is rejected, and a producer in flight causes a stall.
  @(negedge clk);command=program_words[7];command[37+:6]=2;settle();if(command_legal)$fatal(1,"group order");
  bank_busy[6]=1;settle();if(!command_legal || bank_eligible)$fatal(1,"busy producer stall");bank_busy=0;
  run(7,1);if(valid[11] || !valid[6] || !valid[7] || !valid[8])$fatal(1,"failure consumed source or valid dest");
  run(8,0);if(!valid[11] || partial[11] || valid[6] || valid[7] || valid[8])$fatal(1,"reinit success");
  run(9,0);if(!valid[19] || valid[11] || format[19]!=1)$fatal(1,"CAST descriptor");
  run(10,0);if(valid[0] || !assembling[0] || covered_columns[0]!=128)$fatal(1,"assembly start");
  @(negedge clk);command=0;#1;repeat(3)@(negedge clk);if(covered_columns[0]!=128 || !valid[19])$fatal(1,"END retained state");
  @(negedge clk);command=program_words[10];command[144]=0;settle();if(command_legal)$fatal(1,"duplicate insertion");
  for(integer i=11;i<17;i=i+1)run(i,0);
  if(!valid[0] || assembling[0] || covered_columns[0]!=896 || rows[0]!=1 || cols[0]!=896 || tensor[0]!=24 || valid[19])$fatal(1,"final assembly");
  $display("PASS descriptors: DMA, K-group identity/order, partial/final, failure source retention, busy stall, END preservation, ordered layout assembly");$finish;
 end
endmodule
