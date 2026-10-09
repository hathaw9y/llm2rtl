`timescale 1ns/1ps
module tb_attention_math #(parameter integer ALU_COUNT=10194,EXP_COUNT=12064);
 logic aclk=0;always #2.5 aclk=~aclk;
 logic aresetn=0;
 logic cmd_valid=0,cmd_ready,resp_valid,resp_ready=0,resp_error;
 logic [15:0] cmd_id=0,resp_id;
 logic [2:0] cmd_op=0;
 logic [31:0] cmd_a=0,cmd_b=0,resp_data;
 logic e_cmd_valid=0,e_cmd_ready,e_resp_valid,e_resp_ready=0,e_resp_error;
 logic [15:0] e_cmd_id=0,e_resp_id;
 logic [31:0] e_cmd_x=0,e_resp_data;
 logic [99:0] avectors[0:20000];logic [64:0] evectors[0:20000];
 integer na=ALU_COUNT,ne=EXP_COUNT,max_alu=0,max_exp=0;
 attention_fp32_alu u_alu(.*);
 attention_exp_neg u_exp(.aclk,.aresetn,.cmd_valid(e_cmd_valid),.cmd_ready(e_cmd_ready),.cmd_id(e_cmd_id),.cmd_x(e_cmd_x),
 .resp_valid(e_resp_valid),.resp_ready(e_resp_ready),.resp_id(e_resp_id),.resp_data(e_resp_data),.resp_error(e_resp_error));
 task automatic tick;@(posedge aclk);#1;endtask
 initial begin
  $readmemh("alu.hex",avectors,0,ALU_COUNT-1);$readmemh("exp.hex",evectors,0,EXP_COUNT-1);
  repeat(3)tick();@(negedge aclk);aresetn=1;
  for(integer i=0;i<na;i=i+1) begin
   integer elapsed;
   @(negedge aclk);cmd_valid=1;cmd_id=16'(i);cmd_op=avectors[i][99:97];cmd_a=avectors[i][96:65];cmd_b=avectors[i][64:33];
   if(!cmd_ready)$fatal(1,"not idle");tick();@(negedge aclk);cmd_valid=0;
   elapsed=0;
   while(!resp_valid)begin tick();elapsed++;if(elapsed>1500)$fatal(1,"ALU timeout %d",i);end
   if(elapsed>max_alu)max_alu=elapsed;
   if(resp_id!==16'(i) || resp_error!==avectors[i][0] || (!resp_error && resp_data!==avectors[i][32:1]))
    $fatal(1,"ALU mismatch i=%0d op=%d a=%h b=%h got=%h err=%b expected=%h err=%b",i,cmd_op,cmd_a,cmd_b,resp_data,resp_error,avectors[i][32:1],avectors[i][0]);
   repeat(i%4)begin tick();if(!resp_valid || cmd_ready || resp_id!==16'(i) || resp_data!==avectors[i][32:1] || resp_error!==avectors[i][0])$fatal(1,"ALU stalled response");end
   @(negedge aclk);resp_ready=1;tick();@(negedge aclk);resp_ready=0;tick();if(resp_valid)$fatal(1,"extraALUresponse");
  end
  for(integer i=0;i<ne;i=i+1) begin
   integer elapsed;
   @(negedge aclk);e_cmd_valid=1;e_cmd_id=16'(i);e_cmd_x=evectors[i][64:33];
   if(!e_cmd_ready)$fatal(1,"exp not idle");tick();@(negedge aclk);e_cmd_valid=0;
   elapsed=0;
   while(!e_resp_valid)begin tick();elapsed++;if(elapsed>10000)$fatal(1,"exp timeout %d",i);end
   if(elapsed>max_exp)max_exp=elapsed;
   if(e_resp_id!==16'(i) || e_resp_error!==evectors[i][0] || e_resp_data!==evectors[i][32:1])
    $fatal(1,"EXP mismatch i=%0d x=%h got=%h err=%b expected=%h",i,e_cmd_x,e_resp_data,e_resp_error,evectors[i][32:1]);
   repeat(i%3)begin tick();if(!e_resp_valid || e_cmd_ready || e_resp_id!==16'(i) || e_resp_data!==evectors[i][32:1] || e_resp_error!==evectors[i][0])$fatal(1,"EXP stalled response");end
   @(negedge aclk);e_resp_ready=1;tick();@(negedge aclk);e_resp_ready=0;tick();if(e_resp_valid)$fatal(1,"extraEXPresponse");
  end
  // Cancel both engines while working, then while their responses are held.
  for(integer k=0;k<2;k++)begin
   @(negedge aclk);cmd_valid=1;cmd_op=2;cmd_a=32'h3f800000;cmd_b=32'h40400000;e_cmd_valid=1;e_cmd_x=32'hbf800000;
   tick();@(negedge aclk);cmd_valid=0;e_cmd_valid=0;
   if(k==0)repeat(10)tick();else begin while(!resp_valid || !e_resp_valid)tick();end
   @(negedge aclk);aresetn=0;repeat(3)tick();@(negedge aclk);aresetn=1;repeat(5)tick();
   if(resp_valid || e_resp_valid || !cmd_ready || !e_cmd_ready)$fatal(1,"reset cancellation");
  end
  $display("MATH_CASES alu=%0d exp=%0d reset=2",na,ne);
  $display("MATH_MAX_WAIT_CYCLES alu=%0d exp=%0d",max_alu,max_exp);
  $display("ATTENTION_MATH_SIM_PASS");$finish;
 end
 initial begin #1000000000;$fatal(1,"global timeout");end
endmodule
