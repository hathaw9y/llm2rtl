`timescale 1ns/1ps
// Real native bank children/XPM memories, with a task-driven typed DMA transport.
module tb_cmd_dispatcher_extension_probe;
  localparam integer CMD_READ_LATENCY=2;
  localparam integer AXI_ADDR_WIDTH=32,BTT_WIDTH=23,BANK_NUM=2,BANK_NUM_WIDTH=2,TAG_WIDTH=4;
  localparam integer BANK_ADDR_WIDTH=32,CMD_ADDR_WIDTH=3,CMD_DATA_WIDTH=128,MAX_COMMANDS=8,OPCODE_WIDTH=4,PORT_ROLE_WIDTH=3;
  localparam integer O0=CMD_DATA_WIDTH-OPCODE_WIDTH-BANK_NUM_WIDTH;
  localparam integer O1=O0-BANK_NUM_WIDTH,O2=O1-BANK_NUM_WIDTH,OFF=O2-BANK_ADDR_WIDTH,BTT=OFF-BTT_WIDTH,AXI=BTT-AXI_ADDR_WIDTH;
  logic aclk=0,aresetn=0;always #2.5 aclk=~aclk;
  logic cmd_dispatcher_start=0;wire cmd_dispatcher_busy,cmd_dispatcher_done,cmd_dispatcher_error;wire[7:0]cmd_dispatcher_error_code;wire[CMD_ADDR_WIDTH-1:0]current_pc;
  wire cmd_enb;wire[CMD_ADDR_WIDTH-1:0]cmd_addrb;wire[CMD_DATA_WIDTH-1:0]cmd_doutb;
  wire m_ctrl_mm2s_cmd_valid,m_ctrl_s2mm_cmd_valid;
  logic m_ctrl_mm2s_cmd_ready=0,m_ctrl_s2mm_cmd_ready=0;
  wire[31:0]m_ctrl_mm2s_cmd_addr,m_ctrl_s2mm_cmd_addr,m_ctrl_mm2s_cmd_offset,m_ctrl_s2mm_cmd_offset;
  wire[22:0]m_ctrl_mm2s_cmd_btt,m_ctrl_s2mm_cmd_btt;
  wire[1:0]m_ctrl_mm2s_cmd_bank,m_ctrl_s2mm_cmd_bank;wire[3:0]m_ctrl_mm2s_cmd_tag,m_ctrl_s2mm_cmd_tag;
  logic s_ctrl_mm2s_sts_valid=0,s_ctrl_s2mm_sts_valid=0,s_ctrl_mm2s_sts_error=0,s_ctrl_s2mm_sts_error=0;
  logic[3:0]s_ctrl_mm2s_sts_tag=0,s_ctrl_s2mm_sts_tag=0;wire m_ctrl_mm2s_sts_ready,m_ctrl_s2mm_sts_ready;
  wire[1:0]bank_wr_acquire_valid,bank_rd_acquire_valid,bank_wr_release_valid,bank_rd_release_valid,bank_wr_busy,bank_rd_busy;
  wire[1:0][2:0]bank_wr_acquire_port,bank_rd_acquire_port,bank_wr_release_port,bank_rd_release_port,bank_wr_owner_port,bank_rd_owner_port;
  wire[1:0]bank_wr_acquire_accepted,bank_rd_acquire_accepted,bank_wr_release_accepted,bank_rd_release_accepted;
  wire[1:0]native_wr_acquire_accepted,native_rd_acquire_accepted,native_wr_release_accepted,native_rd_release_accepted;
  logic suppress_acquire_ack=0,suppress_release_ack=0,inject_bank_error=0;
  wire native_bank_error,bank_subsystem_error;wire ownership_error,router_error;wire[2:0]bank_subsystem_error_code,ownership_error_code,router_error_code;
  assign bank_subsystem_error=native_bank_error||inject_bank_error;
  assign bank_wr_acquire_accepted=suppress_acquire_ack?2'b0:native_wr_acquire_accepted;
  assign bank_rd_acquire_accepted=suppress_acquire_ack?2'b0:native_rd_acquire_accepted;
  assign bank_wr_release_accepted=suppress_release_ack?2'b0:native_wr_release_accepted;
  assign bank_rd_release_accepted=suppress_release_ack?2'b0:native_rd_release_accepted;
  logic[1:0]external_wr_acquire=0,external_rd_acquire=0,external_wr_release=0,external_rd_release=0;
  wire[1:0]native_wr_acquire_valid=bank_wr_acquire_valid|external_wr_acquire,native_rd_acquire_valid=bank_rd_acquire_valid|external_rd_acquire;
  wire[1:0]native_wr_release_valid=bank_wr_release_valid|external_wr_release,native_rd_release_valid=bank_rd_release_valid|external_rd_release;
  wire[1:0][2:0]native_wr_acquire_port={external_wr_acquire[1]?3'd1:bank_wr_acquire_port[1],external_wr_acquire[0]?3'd1:bank_wr_acquire_port[0]};
  wire[1:0][2:0]native_rd_acquire_port={external_rd_acquire[1]?3'd2:bank_rd_acquire_port[1],external_rd_acquire[0]?3'd2:bank_rd_acquire_port[0]};
  wire[1:0][2:0]native_wr_release_port={external_wr_release[1]?3'd1:bank_wr_release_port[1],external_wr_release[0]?3'd1:bank_wr_release_port[0]};
  wire[1:0][2:0]native_rd_release_port={external_rd_release[1]?3'd2:bank_rd_release_port[1],external_rd_release[0]?3'd2:bank_rd_release_port[0]};
  logic mm2s_bank_ena[0:1];logic[31:0]mm2s_bank_addra[0:1];logic[127:0]mm2s_bank_dina[0:1];logic[15:0]mm2s_bank_wea[0:1];wire mm2s_bank_ready[0:1];
  logic s2mm_bank_enb[0:1];logic[31:0]s2mm_bank_addrb[0:1];wire[127:0]s2mm_bank_doutb[0:1];wire s2mm_bank_read_ready[0:1],s2mm_bank_valid[0:1];
  wire[1:0][32:0]bank_committed_prefix;
  wire m_ctrl_probe_cmd_valid,m_ctrl_probe_sts_ready;
  logic m_ctrl_probe_cmd_ready=0,s_ctrl_probe_sts_valid=0,s_ctrl_probe_sts_error=0;
  wire[1:0]m_ctrl_probe_cmd_src,m_ctrl_probe_cmd_dst;
  logic[1:0]s_ctrl_probe_sts_src=1,s_ctrl_probe_sts_dst=0;
  logic probe_read_enb=0,probe_write_ena=0;logic[31:0]probe_read_addrb=0,probe_write_addra=0;
  logic[127:0]probe_write_dina=0;logic[15:0]probe_write_wea='1;
  wire probe_read_ready,probe_read_valid,probe_write_ready;wire[127:0]probe_read_doutb;
  cmd_dispatcher_template #(.BANK_NUM(BANK_NUM),.BANK_NUM_WIDTH(BANK_NUM_WIDTH),.TAG_WIDTH(TAG_WIDTH),.CMD_ADDR_WIDTH(CMD_ADDR_WIDTH),.MAX_COMMANDS(MAX_COMMANDS),.CMD_READ_LATENCY(CMD_READ_LATENCY),.MM2S_BANK_MASK(2'b11),.S2MM_BANK_MASK(2'b11)) dut(.*);
  controller_test_bank banks(.aclk(aclk),.aresetn(aresetn),
    .bank_wr_acquire_valid(native_wr_acquire_valid),.bank_rd_acquire_valid(native_rd_acquire_valid),.bank_wr_acquire_port(native_wr_acquire_port),.bank_rd_acquire_port(native_rd_acquire_port),
    .bank_wr_release_valid(native_wr_release_valid),.bank_rd_release_valid(native_rd_release_valid),.bank_wr_release_port(native_wr_release_port),.bank_rd_release_port(native_rd_release_port),
    .bank_wr_busy(bank_wr_busy),.bank_rd_busy(bank_rd_busy),.bank_wr_owner_port(bank_wr_owner_port),.bank_rd_owner_port(bank_rd_owner_port),
    .bank_wr_acquire_accepted(native_wr_acquire_accepted),.bank_rd_acquire_accepted(native_rd_acquire_accepted),.bank_wr_release_accepted(native_wr_release_accepted),.bank_rd_release_accepted(native_rd_release_accepted),
    .mm2s_bank_ena(mm2s_bank_ena),.mm2s_bank_addra(mm2s_bank_addra),.mm2s_bank_dina(mm2s_bank_dina),.mm2s_bank_wea(mm2s_bank_wea),.mm2s_bank_ready(mm2s_bank_ready),
    .s2mm_bank_enb(s2mm_bank_enb),.s2mm_bank_addrb(s2mm_bank_addrb),.s2mm_bank_doutb(s2mm_bank_doutb),.s2mm_bank_read_ready(s2mm_bank_read_ready),.s2mm_bank_valid(s2mm_bank_valid),
    .probe_read_enb(probe_read_enb),.probe_read_addrb(probe_read_addrb),.probe_read_ready(probe_read_ready),.probe_read_valid(probe_read_valid),.probe_read_doutb(probe_read_doutb),.probe_write_ena(probe_write_ena),.probe_write_addra(probe_write_addra),.probe_write_dina(probe_write_dina),.probe_write_wea(probe_write_wea),.probe_write_ready(probe_write_ready),
    .bank_committed_prefix(bank_committed_prefix),.bank_subsystem_error(native_bank_error),.ownership_error(ownership_error),.router_error(router_error),.bank_subsystem_error_code(bank_subsystem_error_code),.ownership_error_code(ownership_error_code),.router_error_code(router_error_code));
  logic[127:0]command_mem[0:7],cmd_pipe[0:1];assign cmd_doutb=cmd_pipe[1];
  localparam logic[127:0]PAYLOAD=128'habcdef1234567890_1122334455667788;
  integer wr_count=0,rd_count=0,acquire_count=0,cases=0;
  always @(posedge aclk)begin
    if(!aresetn)begin cmd_pipe[0]<=0;cmd_pipe[1]<=0;wr_count=0;rd_count=0;acquire_count=0;end
    else begin
      if(cmd_enb)cmd_pipe[0]<=command_mem[cmd_addrb];cmd_pipe[1]<=cmd_pipe[0];
      if(bank_wr_acquire_valid[0]||bank_rd_acquire_valid[1])begin
        if(bank_wr_acquire_valid!=1||bank_rd_acquire_valid!=2||bank_wr_acquire_port[0]!=4||bank_rd_acquire_port[1]!=3||bank_wr_acquire_accepted!=1||bank_rd_acquire_accepted!=2)$fatal(1,"probe acquisition not atomic");acquire_count++;
      end
      if(bank_wr_release_valid[0]&&bank_wr_release_accepted[0])begin if(bank_wr_release_port[0]!=4)$fatal(1,"probe writer role");wr_count++;end
      if(bank_rd_release_valid[1]&&bank_rd_release_accepted[1])begin if(bank_rd_release_port[1]!=3)$fatal(1,"probe reader role");rd_count++;end
      if(m_ctrl_probe_cmd_valid&&(!bank_wr_busy[0]||!bank_rd_busy[1]||bank_wr_owner_port[0]!=4||bank_rd_owner_port[1]!=3))$fatal(1,"probe valid before ownership");
    end
  end
  function automatic logic[127:0]command(input integer opcode,input integer dst,input integer src);
    logic[127:0]v;v=0;v[127-:4]=4'(opcode);v[O0+:2]=2'(dst);v[O1+:2]=2'(src);v[BTT+:23]=16;return v;
  endfunction
  task automatic tick;@(posedge aclk);#1.1;@(negedge aclk);endtask
  task automatic reset_dut;
    @(negedge aclk);aresetn=0;cmd_dispatcher_start=0;m_ctrl_mm2s_cmd_ready=0;m_ctrl_s2mm_cmd_ready=0;m_ctrl_probe_cmd_ready=0;s_ctrl_probe_sts_valid=0;s_ctrl_probe_sts_error=0;
    s_ctrl_mm2s_sts_valid=0;s_ctrl_s2mm_sts_valid=0;probe_read_enb=0;probe_write_ena=0;external_wr_acquire=0;external_rd_acquire=0;external_wr_release=0;external_rd_release=0;
    for(integer b=0;b<2;b++)begin mm2s_bank_ena[b]=0;mm2s_bank_addra[b]=0;mm2s_bank_dina[b]=0;mm2s_bank_wea[b]=0;s2mm_bank_enb[b]=0;s2mm_bank_addrb[b]=0;end
    for(integer p=0;p<8;p++)command_mem[p]=0;repeat(3)tick();aresetn=1;tick();
  endtask
  task automatic launch;cmd_dispatcher_start=1;tick();cmd_dispatcher_start=0;endtask
  task automatic wait_probe;
    integer n;n=0;while(!m_ctrl_probe_cmd_valid&&n<80)begin tick();n++;end
    if(!m_ctrl_probe_cmd_valid||m_ctrl_probe_cmd_src!=1||m_ctrl_probe_cmd_dst!=0)$fatal(1,"probe issue timeout/payload");
  endtask
  task automatic probe_status(input integer src,input integer dst,input bit error);
    s_ctrl_probe_sts_src=2'(src);s_ctrl_probe_sts_dst=2'(dst);s_ctrl_probe_sts_error=error;s_ctrl_probe_sts_valid=1;#0.1;if(!m_ctrl_probe_sts_ready)$fatal(1,"probe statusready");tick();s_ctrl_probe_sts_valid=0;s_ctrl_probe_sts_error=0;
  endtask
  task automatic initialize_source;
    // A design-owned external DMA fills source memory before the program starts.
    external_wr_acquire=2;tick();external_wr_acquire=0;
    mm2s_bank_ena[1]=1;mm2s_bank_wea[1]='1;mm2s_bank_dina[1]=PAYLOAD;tick();mm2s_bank_ena[1]=0;
    external_wr_release=2;tick();external_wr_release=0;
  endtask
  task automatic wait_terminal;
    integer n;n=0;while(cmd_dispatcher_busy&&n<80)begin tick();n++;end
    if(cmd_dispatcher_busy)$fatal(1,"probe terminal timeout");
  endtask
  initial begin
    reset_dut();initialize_source();command_mem[0]=command(3,0,1);launch();wait_probe();
    repeat(5)begin if(!m_ctrl_probe_cmd_valid||m_ctrl_probe_cmd_src!=1||m_ctrl_probe_cmd_dst!=0)$fatal(1,"probe backpressure instability");tick();end
    if(acquire_count!=1)$fatal(1,"probe acquired more than once");
    m_ctrl_probe_cmd_ready=1;tick();m_ctrl_probe_cmd_ready=0;
    probe_read_enb=1;#0.1;if(!probe_read_ready||s2mm_bank_read_ready[1])$fatal(1,"probe endpoint isolation");tick();probe_read_enb=0;
    repeat(3)begin
      if(wr_count||rd_count||s_ctrl_probe_sts_valid||!bank_wr_busy[0]||!bank_rd_busy[1])$fatal(1,"probe completion before read response");tick();
    end
    if(!probe_read_valid||probe_read_doutb!==PAYLOAD)$fatal(1,"probe XPM payload/latency");
    probe_write_ena=1;probe_write_dina=probe_read_doutb;#0.1;if(!probe_write_ready||mm2s_bank_ready[0])$fatal(1,"probe write endpoint isolation");tick();probe_write_ena=0;
    if(wr_count||rd_count)$fatal(1,"probe release before final write acceptance");
    probe_status(1,0,0);
    repeat(8)tick();wait_terminal();if(!cmd_dispatcher_done||cmd_dispatcher_error||bank_wr_busy||bank_rd_busy||wr_count!=1||rd_count!=1)$fatal(1,"probe drain/release counts");cases++;
    // Verify the generated compute result through a new DMA-only read owner.
    external_rd_acquire=1;tick();external_rd_acquire=0;s2mm_bank_enb[0]=1;tick();s2mm_bank_enb[0]=0;repeat(3)tick();
    if(!s2mm_bank_valid[0]||s2mm_bank_doutb[0]!==PAYLOAD)$fatal(1,"generated compute result lost");repeat(3)tick();external_rd_release=1;tick();external_rd_release=0;
    // Busy operand prevents partial acquire on the other bank.
    reset_dut();external_wr_acquire=2;tick();external_wr_acquire=0;command_mem[0]=command(3,0,1);launch();repeat(15)tick();
    if(bank_wr_busy[0]||bank_rd_busy||m_ctrl_probe_cmd_valid||acquire_count)$fatal(1,"multioperand partial acquisition");external_wr_release=2;tick();external_wr_release=0;wait_probe();m_ctrl_probe_cmd_ready=1;tick();m_ctrl_probe_cmd_ready=0;probe_status(1,0,0);repeat(8)tick();wait_terminal();if(!cmd_dispatcher_done)$fatal(1,"blocked probe recovery");cases++;
    // Wrong operand completion does not release either owned direction.
    reset_dut();command_mem[0]=command(3,0,1);launch();wait_probe();m_ctrl_probe_cmd_ready=1;tick();m_ctrl_probe_cmd_ready=0;probe_status(0,1,0);repeat(4)tick();
    if(!cmd_dispatcher_error||cmd_dispatcher_error_code!=3||bank_wr_busy!=1||bank_rd_busy!=2||wr_count||rd_count)$fatal(1,"probe mismatch ownership");cases++;
    // The first completion permits one paired release; its duplicate must fault
    // and must never cause a second or unrelated release.
    reset_dut();command_mem[0]=command(3,0,1);launch();wait_probe();m_ctrl_probe_cmd_ready=1;tick();m_ctrl_probe_cmd_ready=0;probe_read_enb=1;tick();probe_read_enb=0;repeat(3)tick();
    if(!probe_read_valid)$fatal(1,"probe duplicate test memory response");tick();
    probe_status(1,0,0);probe_status(1,0,0);repeat(8)tick();
    if(!cmd_dispatcher_error||cmd_dispatcher_error_code!=3||bank_wr_busy||bank_rd_busy||wr_count!=1||rd_count!=1)$fatal(1,"probe duplicate repeated release");cases++;
    // Matching executor failure drains both directions to a terminal error.
    reset_dut();command_mem[0]=command(3,0,1);launch();wait_probe();m_ctrl_probe_cmd_ready=1;tick();m_ctrl_probe_cmd_ready=0;probe_status(1,0,1);repeat(8)tick();wait_terminal();
    if(!cmd_dispatcher_error||cmd_dispatcher_error_code!=4||bank_wr_busy||bank_rd_busy||wr_count!=1||rd_count!=1)$fatal(1,"probe error drain");cases++;
    // Aliased operands are rejected before either acquire.
    reset_dut();command_mem[0]=command(3,0,0);launch();repeat(15)tick();
    if(!cmd_dispatcher_error||cmd_dispatcher_error_code!=2||bank_wr_busy||bank_rd_busy||acquire_count)$fatal(1,"probe operand alias legality");cases++;
    $display("NATIVE_CONTROLLER_EXTENSION_CASES=%0d",cases);
    $display("PASS: marker-only arbitrary-role native extension probe");$finish;
  end
  initial begin #20000;$fatal(1,"extension timeout");end
endmodule
