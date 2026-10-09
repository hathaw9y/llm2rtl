`timescale 1ns/1ps
module tb_qwen_dispatcher;
logic aclk=0;always #5 aclk=~aclk;logic aresetn=0;
logic cmd_dispatcher_start,cmd_dispatcher_busy,cmd_dispatcher_done,cmd_dispatcher_error;
logic [7:0] cmd_dispatcher_error_code;logic [9:0] current_pc,cmd_addrb;logic cmd_enb;
logic [255:0] cmd_doutb;
logic m_ctrl_mm2s_cmd_valid,m_ctrl_mm2s_cmd_ready,s_ctrl_mm2s_sts_valid,m_ctrl_mm2s_sts_ready,s_ctrl_mm2s_sts_error;
logic m_ctrl_s2mm_cmd_valid,m_ctrl_s2mm_cmd_ready,s_ctrl_s2mm_sts_valid,m_ctrl_s2mm_sts_ready,s_ctrl_s2mm_sts_error;
logic [31:0] m_ctrl_mm2s_cmd_addr,m_ctrl_s2mm_cmd_addr,m_ctrl_mm2s_cmd_offset,m_ctrl_s2mm_cmd_offset;
logic [22:0] m_ctrl_mm2s_cmd_btt,m_ctrl_s2mm_cmd_btt;
logic [4:0] m_ctrl_mm2s_cmd_bank,m_ctrl_s2mm_cmd_bank,m_ctrl_mm2s_cmd_tag,m_ctrl_s2mm_cmd_tag,s_ctrl_mm2s_sts_tag,s_ctrl_s2mm_sts_tag;
logic [0:22] bank_acquire_valid,bank_release_valid,bank_busy;
logic [0:22][4:0] bank_acquire_port,bank_release_port,bank_owner_port;
logic [4:0] exec_cmd_valid,exec_cmd_ready,exec_rsp_valid,exec_rsp_ready,exec_rsp_error,exec_commit_valid,exec_commit_error;
logic [255:0] exec_command;logic [9:0] exec_cmd_id;logic [4:0][9:0] exec_rsp_id;
logic [4:0][255:0] exec_commit_command;
logic descriptor_command_legal,descriptor_bank_eligible,ownership_error;logic [2:0] ownership_error_code;
logic [255:0] memory[0:3],cp[0:1];
integer accepts,commits,cycles;
qwen_dispatcher #(.BANK_NUM(23),.BANK_NUM_WIDTH(5),.TAG_WIDTH(5),.PORT_ROLE_WIDTH(5),.CMD_DATA_WIDTH(256)) dut(.*);
bank_ownership_table #(.BANK_NUM(23),.PORT_ROLE_WIDTH(5)) ownership(.aclk,.aresetn,.acquire_valid(bank_acquire_valid),.acquire_port(bank_acquire_port),.release_valid(bank_release_valid),.release_port(bank_release_port),.bank_busy,.bank_owner_port,.ownership_error,.ownership_error_code);
always @*cmd_doutb=cp[1];
always @(posedge aclk)begin
 cp[0]<=cmd_enb?memory[cmd_addrb]:256'b0;cp[1]<=cp[0];
 if(aresetn)begin
  for(integer e=0;e<5;e=e+1)begin
   if(exec_cmd_valid[e] && exec_cmd_ready[e])accepts=accepts+1;
   if(exec_commit_valid[e])commits=commits+1;
  end
  if(ownership_error)$fatal(1,"ownership fault%0d",ownership_error_code);
 end
end
task automatic wait_accept(input integer e,input integer id);
 cycles=0;while(!exec_cmd_valid[e])begin @(negedge aclk);cycles=cycles+1;if(cycles>100)$fatal(1,"accept timeout pc%0d",current_pc);end
 if(exec_cmd_id!=10'(id))$fatal(1,"PC identity");
 @(negedge aclk);
endtask
task automatic respond(input integer e,input integer id,input logic error);
 @(negedge aclk);exec_rsp_valid[e]=1;exec_rsp_id[e]=10'(id);exec_rsp_error[e]=error;
 @(negedge aclk);exec_rsp_valid[e]=0;
endtask
initial begin
 cmd_dispatcher_start=0;m_ctrl_mm2s_cmd_ready=1;m_ctrl_s2mm_cmd_ready=1;s_ctrl_mm2s_sts_valid=0;s_ctrl_s2mm_sts_valid=0;s_ctrl_mm2s_sts_error=0;s_ctrl_s2mm_sts_error=0;s_ctrl_mm2s_sts_tag=0;s_ctrl_s2mm_sts_tag=0;
 exec_cmd_ready='1;exec_rsp_valid=0;exec_rsp_id=0;exec_rsp_error=0;descriptor_command_legal=1;descriptor_bank_eligible=1;accepts=0;commits=0;
 $readmemh("designs/qwen25_05b_w4_shared_zcu104_r1/evidence/dispatcher_control_run001/program.mem",memory);
 repeat(4)@(negedge aclk);aresetn=1;@(negedge aclk);cmd_dispatcher_start=1;@(negedge aclk);cmd_dispatcher_start=0;
 wait_accept(0,0);wait_accept(1,1);
 // PC2 blocks on GEMM destination even though vector is otherwise ready.
 repeat(12)@(negedge aclk);
 if(exec_cmd_valid[4] || current_pc!=2 || !bank_busy[11] || bank_owner_port[11]!=5)$fatal(1,"bank hazard/PC");
 respond(1,1,0);if(bank_busy[0] || bank_busy[22] || bank_busy[1])$fatal(1,"RMS ownership release");
 respond(0,0,0);wait_accept(4,2);repeat(12)@(negedge aclk);
 if(cmd_dispatcher_done || !cmd_dispatcher_busy)$fatal(1,"END drain");
 respond(4,2,0);cycles=0;while(!cmd_dispatcher_done)begin @(negedge aclk);cycles=cycles+1;if(cycles>20)$fatal(1,"DONE timeout");end
 if(cmd_dispatcher_error || accepts!=3 || commits!=3 || |bank_busy)$fatal(1,"terminal state");
 // Reuse command BRAM after normal DONE; no reset of persistent data state.
 @(negedge aclk);cmd_dispatcher_start=1;@(negedge aclk);cmd_dispatcher_start=0;
 wait_accept(0,0);wait_accept(1,1);respond(1,1,0);respond(0,0,1);
 cycles=0;while(!cmd_dispatcher_error)begin @(negedge aclk);cycles=cycles+1;if(cycles>20)$fatal(1,"executor failure drain");end
 if(|bank_busy || exec_cmd_valid[4])$fatal(1,"failure ownership/cancel");
 $display("PASS dispatcher control: distinct executors, PC hazard stall, out-of-order completion, END drain, DONE restart, executor error release. Descriptor/DMA/data payload are outside this test.");$finish;
end
endmodule
