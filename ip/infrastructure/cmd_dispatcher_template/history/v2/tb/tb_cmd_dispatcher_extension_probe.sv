`timescale 1ns/1ps
module tb_cmd_dispatcher_extension_probe;
  localparam integer BANK_NUM=16,PORT_ROLE_WIDTH=3,CMD_READ_LATENCY=2;
  localparam integer OPCODE_LSB=124,OPERAND0_LSB=120,OPERAND1_LSB=116;
  localparam integer LOCAL_OFFSET_LSB=80,BYTE_COUNT_LSB=57;
  logic aclk=0,aresetn=0,cmd_dispatcher_start=0;
  logic cmd_dispatcher_busy,cmd_dispatcher_done,cmd_dispatcher_error;
  logic [7:0] cmd_dispatcher_error_code; logic [9:0] current_pc,cmd_addrb;
  logic cmd_enb; logic [127:0] cmd_doutb;
  logic m_ctrl_mm2s_cmd_valid,m_ctrl_mm2s_cmd_ready=1;
  logic [31:0] m_ctrl_mm2s_cmd_addr,m_ctrl_mm2s_cmd_offset;logic [22:0] m_ctrl_mm2s_cmd_btt;
  logic [3:0] m_ctrl_mm2s_cmd_bank,m_ctrl_mm2s_cmd_tag;
  logic s_ctrl_mm2s_sts_valid=0,m_ctrl_mm2s_sts_ready;logic [3:0] s_ctrl_mm2s_sts_tag=0;logic s_ctrl_mm2s_sts_error=0;
  logic m_ctrl_s2mm_cmd_valid,m_ctrl_s2mm_cmd_ready=1;
  logic [31:0] m_ctrl_s2mm_cmd_addr,m_ctrl_s2mm_cmd_offset;logic [22:0] m_ctrl_s2mm_cmd_btt;
  logic [3:0] m_ctrl_s2mm_cmd_bank,m_ctrl_s2mm_cmd_tag;
  logic s_ctrl_s2mm_sts_valid=0,m_ctrl_s2mm_sts_ready;logic [3:0] s_ctrl_s2mm_sts_tag=0;logic s_ctrl_s2mm_sts_error=0;
  logic [0:BANK_NUM-1] bank_acquire_valid,bank_release_valid,bank_busy;
  logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_acquire_port,bank_release_port,bank_owner_port;
  logic [0:BANK_NUM-1] owned='0,hold='0;
  logic m_user_cmd_valid,m_user_cmd_ready=0;logic [3:0] m_user_cmd_bank0,m_user_cmd_bank1,m_user_cmd_bank2;
  logic s_user_done_valid=0,m_user_done_ready;logic [3:0] s_user_done_bank0=0,s_user_done_bank1=0,s_user_done_bank2=0;
  logic s_user_done_error=0;
  logic [127:0] mem[0:7],pipe[0:1];integer i,model_idx,failures=0;
  cmd_dispatcher_template dut(.*);
  always #2.5 aclk=~aclk;
  assign bank_busy=owned|hold;assign cmd_doutb=pipe[1];
  function automatic logic [127:0] cmd(input logic[3:0]op,input logic[3:0]b0,b1,b2);
    logic[127:0]v;begin v='0;v[127-:4]=op;v[OPCODE_LSB-1-:4]=b0;
      v[OPERAND0_LSB-1-:4]=b1;v[OPERAND1_LSB-1-:4]=b2;
      v[LOCAL_OFFSET_LSB-1-:23]=23'd16;v[BYTE_COUNT_LSB-1-:32]=32'h1000;cmd=v;end
  endfunction
  always_ff @(posedge aclk) begin
    if(!aresetn)begin owned<='0;bank_owner_port<='0;pipe[0]<='0;pipe[1]<='0;end else begin
      if(cmd_enb)pipe[0]<=mem[cmd_addrb];pipe[1]<=pipe[0];
      for(model_idx=0;model_idx<BANK_NUM;model_idx=model_idx+1)begin
        if(bank_release_valid[model_idx])begin owned[model_idx]<=0;bank_owner_port[model_idx]<='0;end
        else if(bank_acquire_valid[model_idx])begin owned[model_idx]<=1;bank_owner_port[model_idx]<=bank_acquire_port[model_idx];end
      end
    end
  end
  task automatic check(input logic ok,input string why);
    begin if(!ok)begin $error("FAIL %s",why);failures=failures+1;end end
  endtask
  task automatic wait_pc(input integer value);integer n;begin for(n=0;n<80&&current_pc!=value;n=n+1)@(posedge aclk);check(current_pc==value,"PC timeout");end endtask
  initial begin
    mem[0]=cmd(1,6,0,0);mem[1]=cmd(3,0,1,2);mem[2]=cmd(0,0,0,0);hold[0]=1;
    repeat(3)@(posedge aclk);@(negedge aclk);aresetn=1;cmd_dispatcher_start=1;
    @(negedge aclk);cmd_dispatcher_start=0;wait_pc(1);check(owned[6]&&bank_owner_port[6]==1,"fixed MM2S role");
    repeat(8)@(posedge aclk);check(current_pc==1&&!m_user_cmd_valid,"busy GEMM operand stalls");
    @(negedge aclk);hold[0]=0;do @(posedge aclk);while(!m_user_cmd_valid);
    check({m_user_cmd_bank0,m_user_cmd_bank1,m_user_cmd_bank2}==12'h012,"GEMM payload");
    repeat(3)begin @(posedge aclk);check(m_user_cmd_valid&&{m_user_cmd_bank0,m_user_cmd_bank1,m_user_cmd_bank2}==12'h012,"GEMM backpressure stability");end
    @(negedge aclk);m_user_cmd_ready=1;#1;
    check(bank_acquire_valid[0]&&bank_acquire_port[0]==3&&
          bank_acquire_valid[1]&&bank_acquire_port[1]==4&&
          bank_acquire_valid[2]&&bank_acquire_port[2]==5,"atomic GEMM role acquire");
    @(posedge aclk);@(negedge aclk);m_user_cmd_ready=0;wait_pc(2);
    check(owned[0]&&owned[1]&&owned[2]&&owned[6],"GEMM and DMA concurrent outstanding");
    @(negedge aclk);s_user_done_bank0=0;s_user_done_bank1=1;s_user_done_bank2=2;s_user_done_valid=1;#1;
    check(bank_release_valid[0]&&bank_release_port[0]==3&&bank_release_valid[1]&&bank_release_port[1]==4&&
          bank_release_valid[2]&&bank_release_port[2]==5&&!bank_release_valid[6],"matching GEMM role release");
    @(posedge aclk);@(negedge aclk);s_user_done_valid=0;s_ctrl_mm2s_sts_tag=6;s_ctrl_mm2s_sts_valid=1;#1;
    check(bank_release_valid[6]&&bank_release_port[6]==1,"fixed DMA role release");
    @(posedge aclk);@(negedge aclk);s_ctrl_mm2s_sts_valid=0;
    for(i=0;i<80&&!cmd_dispatcher_done;i=i+1)@(posedge aclk);
    check(cmd_dispatcher_done&&!cmd_dispatcher_error,"END DONE");
    if(failures==0)begin $display("PASS: marker-only GEMM port-role extension probe");$finish;end
    $fatal(1,"failures=%0d",failures);
  end
endmodule
