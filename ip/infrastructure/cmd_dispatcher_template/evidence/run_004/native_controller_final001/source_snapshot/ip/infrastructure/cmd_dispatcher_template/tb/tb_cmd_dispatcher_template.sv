`timescale 1ns/1ps
// Real native bank children/XPM memories, with a task-driven typed DMA transport.
module tb_cmd_dispatcher_template #(parameter integer CMD_READ_LATENCY=2, parameter bit CAPABILITY_CASE=0);
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
  cmd_dispatcher_template #(.BANK_NUM(BANK_NUM),.BANK_NUM_WIDTH(BANK_NUM_WIDTH),.TAG_WIDTH(TAG_WIDTH),.CMD_ADDR_WIDTH(CMD_ADDR_WIDTH),.MAX_COMMANDS(MAX_COMMANDS),.CMD_READ_LATENCY(CMD_READ_LATENCY),.MM2S_BANK_MASK(CAPABILITY_CASE?2'b01:2'b11),.S2MM_BANK_MASK(2'b11)) dut(.*);
  controller_test_bank banks(.aclk(aclk),.aresetn(aresetn),
    .bank_wr_acquire_valid(native_wr_acquire_valid),.bank_rd_acquire_valid(native_rd_acquire_valid),.bank_wr_acquire_port(native_wr_acquire_port),.bank_rd_acquire_port(native_rd_acquire_port),
    .bank_wr_release_valid(native_wr_release_valid),.bank_rd_release_valid(native_rd_release_valid),.bank_wr_release_port(native_wr_release_port),.bank_rd_release_port(native_rd_release_port),
    .bank_wr_busy(bank_wr_busy),.bank_rd_busy(bank_rd_busy),.bank_wr_owner_port(bank_wr_owner_port),.bank_rd_owner_port(bank_rd_owner_port),
    .bank_wr_acquire_accepted(native_wr_acquire_accepted),.bank_rd_acquire_accepted(native_rd_acquire_accepted),.bank_wr_release_accepted(native_wr_release_accepted),.bank_rd_release_accepted(native_rd_release_accepted),
    .mm2s_bank_ena(mm2s_bank_ena),.mm2s_bank_addra(mm2s_bank_addra),.mm2s_bank_dina(mm2s_bank_dina),.mm2s_bank_wea(mm2s_bank_wea),.mm2s_bank_ready(mm2s_bank_ready),
    .s2mm_bank_enb(s2mm_bank_enb),.s2mm_bank_addrb(s2mm_bank_addrb),.s2mm_bank_doutb(s2mm_bank_doutb),.s2mm_bank_read_ready(s2mm_bank_read_ready),.s2mm_bank_valid(s2mm_bank_valid),
    .bank_committed_prefix(bank_committed_prefix),.bank_subsystem_error(native_bank_error),.ownership_error(ownership_error),.router_error(router_error),.bank_subsystem_error_code(bank_subsystem_error_code),.ownership_error_code(ownership_error_code),.router_error_code(router_error_code));
  logic[127:0]command_mem[0:7],cmd_pipe[0:CMD_READ_LATENCY-1];
  integer fetch_count=0,mm_commands=0,ss_commands=0,wr_releases=0,rd_releases=0,cases=0,response_count=0;
  logic check_payload=0;logic expected_valid[0:3];logic[127:0]expected_data[0:3];
  function automatic logic[127:0]payload(input integer addr);return 128'h123456789abcdef0_fedcba9876543210+128'(addr);endfunction
  assign cmd_doutb=cmd_pipe[CMD_READ_LATENCY-1];
  always @(posedge aclk)begin
    if(!aresetn)begin
      fetch_count=0;mm_commands=0;ss_commands=0;wr_releases=0;rd_releases=0;response_count=0;
      for(integer p=0;p<CMD_READ_LATENCY;p++)cmd_pipe[p]<=0;
      for(integer p=0;p<4;p++)expected_valid[p]=0;
    end else begin
      if(cmd_enb)begin cmd_pipe[0]<=command_mem[cmd_addrb];fetch_count++;end
      for(integer p=1;p<CMD_READ_LATENCY;p++)cmd_pipe[p]<=cmd_pipe[p-1];
      if(m_ctrl_mm2s_cmd_valid&&m_ctrl_mm2s_cmd_ready)begin
        if(!bank_wr_busy[m_ctrl_mm2s_cmd_bank]||bank_wr_owner_port[m_ctrl_mm2s_cmd_bank]!=1)$fatal(1,"MM command before acquisition");mm_commands++;
      end
      if(m_ctrl_s2mm_cmd_valid&&m_ctrl_s2mm_cmd_ready)begin
        if(!bank_rd_busy[m_ctrl_s2mm_cmd_bank]||bank_rd_owner_port[m_ctrl_s2mm_cmd_bank]!=2)$fatal(1,"S command before acquisition");ss_commands++;
      end
      for(integer b=0;b<2;b++)begin
        if(bank_wr_release_valid[b]&&native_wr_release_accepted[b])begin if(bank_wr_release_port[b]!=1)$fatal(1,"MM release role");wr_releases++;end
        if(bank_rd_release_valid[b]&&native_rd_release_accepted[b])begin if(bank_rd_release_port[b]!=2)$fatal(1,"S release role");rd_releases++;end
      end
      for(integer p=3;p>0;p--)begin expected_valid[p]=expected_valid[p-1];expected_data[p]=expected_data[p-1];end
      expected_valid[0]=check_payload&&s2mm_bank_enb[0]&&s2mm_bank_read_ready[0];
      expected_data[0]=payload(s2mm_bank_addrb[0]);
    end
    #1;
    if(check_payload)begin
      if(s_ctrl_s2mm_sts_valid&&response_count!=4)$fatal(1,"engine status before all memory responses consumed");
      if(s2mm_bank_valid[0]!==expected_valid[3])$fatal(1,"native response latency");
      if(expected_valid[3])begin if(s2mm_bank_doutb[0]!==expected_data[3])$fatal(1,"native DMA roundtrip payload");response_count++;end
    end
    if(cmd_dispatcher_done&&(bank_wr_busy||bank_rd_busy))$fatal(1,"END before global drain");
  end
  function automatic logic[127:0]command(input integer op,input integer bank,input integer offset,input integer count,input logic[31:0]axi);
    logic[127:0]v;v='0;v[127-:4]=4'(op);v[O0+:2]=2'(bank);v[O1+:2]=2;v[O2+:2]=3;v[OFF+:32]=32'(offset);v[BTT+:23]=23'(count);v[AXI+:32]=axi;v[AXI-1:0]='1;return v;
  endfunction
  task automatic tick;@(posedge aclk);#1.1;@(negedge aclk);endtask
  task automatic reset_dut;
    @(negedge aclk);aresetn=0;cmd_dispatcher_start=0;m_ctrl_mm2s_cmd_ready=0;m_ctrl_s2mm_cmd_ready=0;
    s_ctrl_mm2s_sts_valid=0;s_ctrl_s2mm_sts_valid=0;s_ctrl_mm2s_sts_error=0;s_ctrl_s2mm_sts_error=0;
    external_wr_acquire=0;external_rd_acquire=0;external_wr_release=0;external_rd_release=0;suppress_acquire_ack=0;suppress_release_ack=0;inject_bank_error=0;check_payload=0;
    for(integer b=0;b<2;b++)begin mm2s_bank_ena[b]=0;mm2s_bank_addra[b]=0;mm2s_bank_dina[b]=0;mm2s_bank_wea[b]=0;s2mm_bank_enb[b]=0;s2mm_bank_addrb[b]=0;end
    repeat(3)tick();aresetn=1;tick();
    if(cmd_dispatcher_busy||cmd_dispatcher_done||cmd_dispatcher_error||bank_wr_busy||bank_rd_busy)$fatal(1,"reset failed");
    for(integer p=0;p<8;p++)command_mem[p]=0;
  endtask
  task automatic launch;cmd_dispatcher_start=1;tick();cmd_dispatcher_start=0;endtask
  task automatic wait_valid(input bit reader);
    integer n;n=0;while(!(reader?m_ctrl_s2mm_cmd_valid:m_ctrl_mm2s_cmd_valid)&&n<100)begin tick();n++;end
    if(!(reader?m_ctrl_s2mm_cmd_valid:m_ctrl_mm2s_cmd_valid))$fatal(1,"command valid timeout pc%0d state%0d",current_pc,dut.state_r);
  endtask
  task automatic check_command(input bit reader,input logic[127:0]record);
    if(reader)begin
      if(!m_ctrl_s2mm_cmd_valid||m_ctrl_s2mm_cmd_addr!==record[AXI+:32]||m_ctrl_s2mm_cmd_btt!==record[BTT+:23]||m_ctrl_s2mm_cmd_offset!==record[OFF+:32]||m_ctrl_s2mm_cmd_bank!==record[O0+:2]||m_ctrl_s2mm_cmd_tag!=={2'b0,record[O0+:2]})$fatal(1,"S command unstable or incorrect");
      if(!bank_rd_busy[m_ctrl_s2mm_cmd_bank]||bank_rd_owner_port[m_ctrl_s2mm_cmd_bank]!=2)$fatal(1,"S valid before ownership");
    end else begin
      if(!m_ctrl_mm2s_cmd_valid||m_ctrl_mm2s_cmd_addr!==record[AXI+:32]||m_ctrl_mm2s_cmd_btt!==record[BTT+:23]||m_ctrl_mm2s_cmd_offset!==record[OFF+:32]||m_ctrl_mm2s_cmd_bank!==record[O0+:2]||m_ctrl_mm2s_cmd_tag!=={2'b0,record[O0+:2]})$fatal(1,"MM command unstable or incorrect");
      if(!bank_wr_busy[m_ctrl_mm2s_cmd_bank]||bank_wr_owner_port[m_ctrl_mm2s_cmd_bank]!=1)$fatal(1,"MM valid before ownership");
    end
  endtask
  task automatic accept_command(input bit reader,input logic[127:0]record,input integer stall);
    wait_valid(reader);repeat(stall)begin check_command(reader,record);tick();end
    check_command(reader,record);if(reader)m_ctrl_s2mm_cmd_ready=1;else m_ctrl_mm2s_cmd_ready=1;tick();m_ctrl_s2mm_cmd_ready=0;m_ctrl_mm2s_cmd_ready=0;
  endtask
  task automatic status(input bit reader,input integer tag,input bit error);
    if(reader)begin s_ctrl_s2mm_sts_valid=1;s_ctrl_s2mm_sts_tag=4'(tag);s_ctrl_s2mm_sts_error=error;end
    else begin s_ctrl_mm2s_sts_valid=1;s_ctrl_mm2s_sts_tag=4'(tag);s_ctrl_mm2s_sts_error=error;end
    #0.1;if(!(reader?m_ctrl_s2mm_sts_ready:m_ctrl_mm2s_sts_ready))$fatal(1,"completion not accepted");tick();s_ctrl_mm2s_sts_valid=0;s_ctrl_s2mm_sts_valid=0;s_ctrl_mm2s_sts_error=0;s_ctrl_s2mm_sts_error=0;
  endtask
  task automatic drain_bank(input bit reader,input integer bank);
    integer n;n=0;while((reader?bank_rd_busy[bank]:bank_wr_busy[bank])&&n<30)begin tick();n++;end
    if(reader?bank_rd_busy[bank]:bank_wr_busy[bank])$fatal(1,"release timeout");
  endtask
  task automatic done;
    integer n;n=0;while(!cmd_dispatcher_done&&n<100)begin tick();n++;end
    if(!cmd_dispatcher_done||cmd_dispatcher_error)$fatal(1,"DONE timeout/error code%0d",cmd_dispatcher_error_code);
  endtask
  task automatic error_code(input integer code);
    integer n;n=0;while(!cmd_dispatcher_error&&n<100)begin tick();n++;end
    if(!cmd_dispatcher_error||cmd_dispatcher_error_code!=code)$fatal(1,"error expected%0d got%0d",code,cmd_dispatcher_error_code);
  endtask
  task automatic terminal_error(input integer code);
    integer n;error_code(code);n=0;while(cmd_dispatcher_busy&&n<100)begin tick();n++;end
    if(cmd_dispatcher_busy||cmd_dispatcher_done||bank_wr_busy||bank_rd_busy)$fatal(1,"soft error failed to drain to terminal");
  endtask
  initial begin : cases_block
    logic[127:0]c0,c1;integer before_fetch,before_release;
    if(CAPABILITY_CASE)begin
      reset_dut();command_mem[0]=command(1,1,0,64,0);launch();terminal_error(2);
      if(mm_commands||ss_commands||bank_wr_busy||bank_rd_busy)$fatal(1,"unsupported capability touched bank");
      $display("CASE DMA bank capability mask reject PASS");
      $display("PASS: cmd_dispatcher_template native controller verification");$finish;
    end
    reset_dut();c0=command(1,0,0,64,32'h81234567);c1=command(2,0,0,64,32'habcd0000);command_mem[0]=c0;command_mem[1]=c1;launch();accept_command(0,c0,4);
    // Current-PC same-bank read must wait despite independently free read owner.
    repeat(12)tick();before_fetch=fetch_count;
    repeat(5)begin if(current_pc!=1||m_ctrl_s2mm_cmd_valid)$fatal(1,"same-bank lookahead");tick();end
    if(fetch_count!=before_fetch)$fatal(1,"repeated fetch while bank blocked");
    for(integer addr=0;addr<4;addr++)begin mm2s_bank_ena[0]=1;mm2s_bank_addra[0]=addr;mm2s_bank_wea[0]='1;mm2s_bank_dina[0]=payload(addr);#0.1;if(!mm2s_bank_ready[0])$fatal(1,"MM native not ready");tick();end
    mm2s_bank_ena[0]=0;status(0,0,0);drain_bank(0,0);accept_command(1,c1,3);check_payload=1;
    for(integer addr=0;addr<4;addr++)begin s2mm_bank_enb[0]=1;s2mm_bank_addrb[0]=addr;tick();end
    s2mm_bank_enb[0]=0;before_release=rd_releases;
    while(response_count!=4)begin
      if(!bank_rd_busy[0]||rd_releases!=before_release||s_ctrl_s2mm_sts_valid)$fatal(1,"completion/release before final memory response");tick();
    end
    if(!bank_rd_busy[0]||rd_releases!=before_release)$fatal(1,"owner not retained until engine completion");
    tick(); // Engine consumes/processes the last response before completion.
    status(1,0,0);
    drain_bank(1,0);repeat(3)tick();if(response_count!=4||rd_releases!=before_release+1||wr_releases!=1)$fatal(1,"payload/release count");done();cases++;$display("CASE native DMA payload/stall/same-bank/drain PASS");
    // Repeated start without reset, bank0 reuse, completion on acceptance edge.
    check_payload=0;command_mem[0]=c0;command_mem[1]=0;launch();wait_valid(0);m_ctrl_mm2s_cmd_ready=1;s_ctrl_mm2s_sts_valid=1;s_ctrl_mm2s_sts_tag=0;tick();m_ctrl_mm2s_cmd_ready=0;s_ctrl_mm2s_sts_valid=0;drain_bank(0,0);done();cases++;
    reset_dut();c0=command(1,0,9,48,32'h10203040);c1=command(1,1,15,96,32'h40506070);command_mem[0]=c0;command_mem[1]=c1;launch();accept_command(0,c0,1);accept_command(0,c1,2);
    if(bank_wr_busy!=3||mm_commands!=2)$fatal(1,"distinct MM overlap");repeat(10)tick();if(cmd_dispatcher_done)$fatal(1,"END ignored outstanding");status(0,1,0);status(0,0,0);done();cases++;
    reset_dut();c0=command(1,0,0,64,32'h1000);c1=command(2,1,0,64,32'h2000);command_mem[0]=c0;command_mem[1]=c1;launch();accept_command(0,c0,2);accept_command(1,c1,2);
    if(!bank_wr_busy[0]||!bank_rd_busy[1])$fatal(1,"mixed overlap");status(0,0,0);status(1,1,0);done();cases++;
    // Wrong-type asynchronous status while second engine command remains stalled.
    reset_dut();c0=command(1,0,17,64,32'h11220000);c1=command(1,1,29,32,32'h99887766);command_mem[0]=c0;command_mem[1]=c1;launch();accept_command(0,c0,0);wait_valid(0);
    cmd_dispatcher_start=1;tick();cmd_dispatcher_start=0;status(1,0,0);error_code(3);
    repeat(5)begin check_command(0,c1);tick();end
    if(!bank_wr_busy[0])$fatal(1,"wrong type released active writer");accept_command(0,c1,2);repeat(5)tick();if(bank_wr_busy!=3||wr_releases)$fatal(1,"invalid response recovery must retain owners");error_code(3);cases++;
    // Duplicate completed response, stale old-engine response after bank reuse,
    // and out-of-range tag cannot release unrelated/new ownership.
    reset_dut();command_mem[0]=command(1,0,0,64,0);command_mem[1]=command(2,0,0,64,0);launch();accept_command(0,command_mem[0],0);status(0,0,0);drain_bank(0,0);accept_command(1,command_mem[1],0);
    status(0,0,0);error_code(3);if(!bank_rd_busy[0])$fatal(1,"stale writer response released reader");cases++;
    reset_dut();command_mem[0]=command(2,0,0,64,0);launch();accept_command(1,command_mem[0],0);status(1,2,0);error_code(3);if(!bank_rd_busy[0]||rd_releases)$fatal(1,"outofrange response released reader");cases++;
    reset_dut();command_mem[0]=command(2,0,0,64,0);launch();accept_command(1,command_mem[0],0);
    s2mm_bank_enb[0]=1;s2mm_bank_addrb[0]=0;tick();s2mm_bank_enb[0]=0;repeat(3)tick();
    if(!s2mm_bank_valid[0])$fatal(1,"duplicate testcase memory completion missing");tick();
    status(1,0,0);status(1,0,0);error_code(3);repeat(6)tick();
    if(bank_rd_busy[0]||rd_releases!=1||wr_releases)$fatal(1,"duplicate repeated or unrelated release");cases++;
    reset_dut();command_mem[0]=command(2,0,0,64,0);launch();accept_command(1,command_mem[0],0);status(1,0,1);drain_bank(1,0);terminal_error(4);cases++;
    // Matching executor error is soft: retire earlier command while keeping
    // the next already-presented request stable, then finish a complete drain.
    reset_dut();c0=command(1,0,13,64,32'h13243546);c1=command(1,1,23,48,32'habcdef01);command_mem[0]=c0;command_mem[1]=c1;launch();accept_command(0,c0,0);wait_valid(0);
    status(0,0,1);error_code(4);repeat(4)begin check_command(0,c1);tick();end
    accept_command(0,c1,2);status(0,1,0);drain_bank(0,0);drain_bank(0,1);terminal_error(4);cases++;
    // END observes external owners in both directions, not just tracked DMA.
    reset_dut();external_wr_acquire=1;external_rd_acquire=2;tick();external_wr_acquire=0;external_rd_acquire=0;launch();repeat(20)tick();if(cmd_dispatcher_done)$fatal(1,"END ignored external owners");
    external_wr_release=1;tick();external_wr_release=0;repeat(4)tick();if(cmd_dispatcher_done)$fatal(1,"END ignored external reader");external_rd_release=2;tick();external_rd_release=0;done();cases++;
    // Unknown operation, bad bank and zero byte count fault before engine issue.
    for(integer bad=0;bad<3;bad++)begin reset_dut();command_mem[0]=command(bad==0?7:1,bad==1?2:0,0,bad==2?0:64,0);launch();error_code(bad==0?1:2);
      if(mm_commands||ss_commands||bank_wr_busy||bank_rd_busy)$fatal(1,"illegal command touched banks");terminal_error(bad==0?1:2);end cases++;
    // Ack failure is fail-stop until coordinated controller/bank reset.
    reset_dut();command_mem[0]=command(1,0,0,64,0);suppress_acquire_ack=1;launch();error_code(8);repeat(5)tick();if(m_ctrl_mm2s_cmd_valid||!bank_wr_busy[0])$fatal(1,"failed acquire ack issued or released");cases++;
    reset_dut();command_mem[0]=command(1,0,0,64,0);launch();accept_command(0,command_mem[0],0);suppress_release_ack=1;status(0,0,0);error_code(8);cases++;
    // Native subsystem failure during backpressure still preserves accepted duty.
    reset_dut();c0=command(1,0,31,64,32'h98765432);command_mem[0]=c0;launch();wait_valid(0);inject_bank_error=1;tick();error_code(7);repeat(4)begin check_command(0,c0);tick();end
    accept_command(0,c0,0);repeat(5)tick();if(!bank_wr_busy[0])$fatal(1,"hard fault arbitrarily released bank");cases++;
    // Reset from fetched/stalled/pending states clears all bank and controller state.
    reset_dut();command_mem[0]=command(1,0,0,64,0);launch();tick();reset_dut();command_mem[0]=command(1,0,0,64,0);launch();wait_valid(0);reset_dut();command_mem[0]=command(1,0,0,64,0);launch();accept_command(0,command_mem[0],0);reset_dut();cases++;
    // Bounded missing-END uses every command word and retires all transfers.
    for(integer p=0;p<8;p++)command_mem[p]=command(1,p%2,p,16,32'hb0000000+32'(p));launch();
    for(integer p=0;p<8;p++)begin accept_command(0,command_mem[p],0);status(0,p%2,0);drain_bank(0,p%2);end
    terminal_error(5);if(current_pc!=7)$fatal(1,"missing END PC");cases++;
    $display("NATIVE_CONTROLLER_CASES=%0d CMD_READ_LATENCY=%0d",cases,CMD_READ_LATENCY);
    $display("PASS: cmd_dispatcher_template native controller verification");$finish;
  end
  initial begin #100000;$fatal(1,"controller timeout");end
endmodule
