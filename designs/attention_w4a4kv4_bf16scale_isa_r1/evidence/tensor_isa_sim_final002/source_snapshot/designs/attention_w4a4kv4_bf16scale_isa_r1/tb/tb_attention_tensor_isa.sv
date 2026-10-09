`timescale 1ns/1ps
module tb_attention_tensor_isa #(parameter integer CMD_READ_LATENCY=1, NEGATIVE_TESTS=1);
 localparam integer CMD_ADDR_WIDTH=6,MAX_COMMANDS=64,WORDS=4096;
 import attention_tensor_pkg::*;
 import attention_tensor_config_pkg::*;
 logic  aclk=0;
 logic  aresetn=0;
 logic  cmd_dispatcher_start=0;
 wire  cmd_dispatcher_busy;
 wire  cmd_dispatcher_done;
 wire  cmd_dispatcher_error;
 wire [7:0] cmd_dispatcher_error_code;
 wire [CMD_ADDR_WIDTH-1:0] cmd_dispatcher_current_pc;
 wire  cmd_enb;
 wire [CMD_ADDR_WIDTH-1:0] cmd_addrb;
 wire [127:0] cmd_doutb;
 wire  m_ctrl_mm2s_cmd_valid;
 logic  m_ctrl_mm2s_cmd_ready=0;
 wire [31:0] m_ctrl_mm2s_cmd_addr;
 wire [22:0] m_ctrl_mm2s_cmd_btt;
 wire [22:0] m_ctrl_mm2s_cmd_offset;
 wire [4:0] m_ctrl_mm2s_cmd_bank;
 wire  m_ctrl_s2mm_cmd_valid;
 logic  m_ctrl_s2mm_cmd_ready=0;
 wire [31:0] m_ctrl_s2mm_cmd_addr;
 wire [22:0] m_ctrl_s2mm_cmd_btt;
 wire [22:0] m_ctrl_s2mm_cmd_offset;
 wire [4:0] m_ctrl_s2mm_cmd_bank;
 logic  s_ctrl_mm2s_sts_valid=0;
 wire  m_ctrl_mm2s_sts_ready;
 logic [4:0] s_ctrl_mm2s_sts_bank=0;
 logic  s_ctrl_mm2s_sts_error=0;
 logic  s_ctrl_mm2s_faulted=0;
 logic  s_ctrl_s2mm_sts_valid=0;
 wire  m_ctrl_s2mm_sts_ready;
 logic [4:0] s_ctrl_s2mm_sts_bank=0;
 logic  s_ctrl_s2mm_sts_error=0;
 logic  s_ctrl_s2mm_faulted=0;
 wire [18:0] bank_valid;
 logic  mm2s_write_valid=0;
 wire  mm2s_write_ready;
 logic [4:0] mm2s_write_bank=0;
 logic [31:0] mm2s_write_addr=0;
 logic [127:0] mm2s_write_data=0;
 logic [15:0] mm2s_write_strb=0;
 logic  s2mm_read_valid=0;
 wire  s2mm_read_ready;
 logic [4:0] s2mm_read_bank=0;
 logic [31:0] s2mm_read_addr=0;
 wire  s2mm_rsp_valid;
 wire [4:0] s2mm_rsp_bank;
 wire [127:0] s2mm_rsp_data;
 wire  bank_error;
 wire [18:0] bank_busy;
 wire [18:0][2:0] bank_owner_port;
 always #2.5 aclk=~aclk;
 attention_tensor_isa_top #(.CMD_ADDR_WIDTH(CMD_ADDR_WIDTH),.MAX_COMMANDS(MAX_COMMANDS),.CMD_READ_LATENCY(CMD_READ_LATENCY)) dut(.*);
 logic [127:0] program_words[0:63],canonical[0:20],diagnostic[0:33];
 logic [127:0] input_words[0:6*WORDS-1],golden_words[0:19*WORDS-1];
 logic [127:0] cmd_pipe[0:CMD_READ_LATENCY-1];
 integer cycle=0,cases=0,mm_count=0,ss_count=0,compute_count=0,acquires=0,releases=0;
 integer pending0=0,pending1=0,ss_issued=0,ss_received=0;
 logic [4:0] ss_bank=0;logic ss_active=0,auto_dma=0,mm_clean_error=0;
 logic [18:0] active_mask=0;logic [18:0][2:0] active_roles=0;
 logic [15:0] saved_compute_id=0;
 integer mm_data_writes=0,compute_writes=0,physical_writes=0,physical_reads=0;
 logic compute_retired=0,late_fault_active=0;
 assign cmd_doutb=cmd_pipe[CMD_READ_LATENCY-1];
 always @(posedge aclk)begin
  if(cmd_enb)cmd_pipe[0]<=program_words[cmd_addrb];
  for(integer p=1;p<CMD_READ_LATENCY;p++)cmd_pipe[p]<=cmd_pipe[p-1];
  if(!aresetn)begin pending0=0;pending1=0;active_mask=0;active_roles=0;ss_issued=0;ss_received=0;compute_retired=0;end
  else begin
   cycle++;
   for(integer b=0;b<19;b++)begin
    if(dut.u_banks.mem_ena[b] && (|dut.u_banks.mem_wea[b]))begin
     if(!bank_busy[b] || (bank_owner_port[b]!=1 && bank_owner_port[b]!=5))$fatal(1,"physicalwritewrongowner");physical_writes++;
    end
    if(dut.u_banks.mem_enb[b])begin
     if(!bank_busy[b] || bank_owner_port[b]<2 || bank_owner_port[b]>4)$fatal(1,"physicalreadwrongowner");physical_reads++;
    end
   end
   if(compute_retired && (dut.src0_read_valid || dut.src1_read_valid || dut.dst_write_valid))$fatal(1,"compute request after completion");
   if(dut.compute_resp_valid&&dut.compute_resp_ready)compute_retired=1;
   if(dut.src0_read_valid&&dut.src0_read_ready)begin
    if(bank_owner_port[dut.src0_read_bank]!=3 || !bank_busy[dut.src0_read_bank] || pending0!=0)$fatal(1,"src0 ownership/pending");pending0++;
   end
   if(dut.src1_read_valid&&dut.src1_read_ready)begin
    if(bank_owner_port[dut.src1_read_bank]!=4 || !bank_busy[dut.src1_read_bank] || pending1!=0)$fatal(1,"src1 ownership/pending");pending1++;
   end
   if(dut.src0_rsp_valid)begin if(pending0!=1)$fatal(1,"unexpectedsrc0response");pending0--;end
   if(dut.src1_rsp_valid)begin if(pending1!=1)$fatal(1,"unexpectedsrc1response");pending1--;end
   if(dut.dst_write_valid&&dut.dst_write_ready)begin
    if(bank_owner_port[dut.dst_write_bank]!=5 || !bank_busy[dut.dst_write_bank] || dut.dst_write_strb!=16'hffff || dut.dst_write_addr>=capacity_words(dut.dst_write_bank))$fatal(1,"compute writeownership/range");compute_writes++;
   end
   if(mm2s_write_valid&&mm2s_write_ready)begin
    if(!bank_busy[mm2s_write_bank] || bank_owner_port[mm2s_write_bank]!=1 || mm2s_write_addr>=capacity_words(mm2s_write_bank))$fatal(1,"MMwriteownership/range");mm_data_writes++;
   end
   if(s2mm_read_valid&&s2mm_read_ready)begin
    if(!ss_active || s2mm_read_bank!=ss_bank || s2mm_read_addr!=32'(ss_issued) || bank_owner_port[ss_bank]!=2)$fatal(1,"SSreadrequest");ss_issued++;
   end
   if(s2mm_rsp_valid)begin
    if(!ss_active || s2mm_rsp_bank!=ss_bank || ss_received>=ss_issued || s2mm_rsp_data!==golden_words[int'(ss_bank)*WORDS+ss_received])$fatal(1,"SSpayload bank%0d word%0d got%h expected%h",ss_bank,ss_received,s2mm_rsp_data,golden_words[int'(ss_bank)*WORDS+ss_received]);ss_received++;
   end
   if(dut.compute_resp_valid)begin
    if(pending0 || pending1 || dut.src0_read_valid || dut.src1_read_valid || dut.dst_write_valid)$fatal(1,"compute completed before memory drained");
   end
   if(|dut.bank_acquire_valid)begin
    logic [18:0] mask;logic[18:0][2:0]roles;
    mask=0;roles=0;
    if(m_ctrl_mm2s_cmd_valid&&m_ctrl_mm2s_cmd_ready)begin mask[m_ctrl_mm2s_cmd_bank]=1;roles[m_ctrl_mm2s_cmd_bank]=1;mm_count++;end
    else if(m_ctrl_s2mm_cmd_valid&&m_ctrl_s2mm_cmd_ready)begin mask[m_ctrl_s2mm_cmd_bank]=1;roles[m_ctrl_s2mm_cmd_bank]=2;ss_count++;end
    else if(dut.compute_cmd_valid&&dut.compute_cmd_ready)begin
     mask[dut.compute_cmd_src0]=1;roles[dut.compute_cmd_src0]=3;
     mask[dut.compute_cmd_dst]=1;roles[dut.compute_cmd_dst]=5;
     if(dut.compute_cmd_opcode!=3)begin mask[dut.compute_cmd_src1]=1;roles[dut.compute_cmd_src1]=4;end
     saved_compute_id=dut.compute_cmd_id;compute_count++;compute_retired=0;
    end else $fatal(1,"acquisition without engine accept");
    if(active_mask!=0 || dut.bank_acquire_valid!==mask || dut.bank_acquire_accepted!==mask || dut.bank_acquire_port!==roles)$fatal(1,"nonatomic acquisition");active_mask=mask;active_roles=roles;acquires++;
   end
   if(late_fault_active && bank_error)begin
    if(|dut.bank_release_accepted)$fatal(1,"fault accepted ownership release");
   end else if(|dut.bank_release_valid)begin
    if(active_mask==0 || dut.bank_release_valid!==active_mask || dut.bank_release_accepted!==active_mask || dut.bank_release_port!==active_roles || pending0 || pending1)$fatal(1,"nonatomic/unrelated release");
    for(integer b=0;b<19;b++)if(active_mask[b] && (!bank_busy[b] || bank_owner_port[b]!=active_roles[b]))$fatal(1,"releasewrongowner");
    active_mask=0;active_roles=0;releases++;
   end
   if(cmd_dispatcher_done && (bank_busy!=0 || active_mask!=0 || pending0 || pending1))$fatal(1,"END before globaldrain");
   if(bank_error && auto_dma)$fatal(1,"unexpected bankerror PC%0d",cmd_dispatcher_current_pc);
  end
 end
 task automatic tick;@(posedge aclk);#1;endtask
 task automatic reset_dut;
  @(negedge aclk);aresetn=0;cmd_dispatcher_start=0;auto_dma=0;
  m_ctrl_mm2s_cmd_ready=0;m_ctrl_s2mm_cmd_ready=0;s_ctrl_mm2s_sts_valid=0;s_ctrl_s2mm_sts_valid=0;
  s_ctrl_mm2s_sts_error=0;s_ctrl_s2mm_sts_error=0;s_ctrl_mm2s_faulted=0;s_ctrl_s2mm_faulted=0;
  mm2s_write_valid=0;s2mm_read_valid=0;ss_active=0;mm_clean_error=0;late_fault_active=0;
  repeat(4)tick();@(negedge aclk);aresetn=1;repeat(3)tick();
  if(bank_busy || bank_valid || bank_error || cmd_dispatcher_error)$fatal(1,"resetdidnotclear");
 endtask
 task automatic start_program;
  @(negedge aclk);cmd_dispatcher_start=1;tick();@(negedge aclk);cmd_dispatcher_start=0;
 endtask
 task automatic terminal(input logic error,input integer code);
  integer elapsed;elapsed=0;
  while(cmd_dispatcher_busy)begin tick();elapsed++;if(elapsed>32000000)$fatal(1,"program timeout PC%0d ctl%0d executor%0d",cmd_dispatcher_current_pc,dut.u_controller.state_r,dut.u_executor.state_r);end
  if(cmd_dispatcher_error!==error || (error && cmd_dispatcher_error_code!=8'(code)) || (!error && !cmd_dispatcher_done))$fatal(1,"terminal goterror%b code%d done%b expected%d",cmd_dispatcher_error,cmd_dispatcher_error_code,cmd_dispatcher_done,code);
 endtask
 task automatic mm_transfer;
  logic[4:0]bank;logic[86:0]held;integer words;
  bank=m_ctrl_mm2s_cmd_bank;held={m_ctrl_mm2s_cmd_addr,m_ctrl_mm2s_cmd_btt,m_ctrl_mm2s_cmd_offset,bank};words=int'(capacity_words(bank));
  if(bank>=6 || m_ctrl_mm2s_cmd_btt!=32'(words*16) || m_ctrl_mm2s_cmd_offset!=0 || m_ctrl_mm2s_cmd_addr!==program_words[cmd_dispatcher_current_pc][31:0])$fatal(1,"MMcommandfields");
  repeat(3)begin tick();if(!m_ctrl_mm2s_cmd_valid || {m_ctrl_mm2s_cmd_addr,m_ctrl_mm2s_cmd_btt,m_ctrl_mm2s_cmd_offset,m_ctrl_mm2s_cmd_bank}!==held || bank_busy!=0)$fatal(1,"MMcommandstallchanged/acquired");end
  @(negedge aclk);m_ctrl_mm2s_cmd_ready=1;tick();@(negedge aclk);m_ctrl_mm2s_cmd_ready=0;
  if(!bank_busy[bank] || bank_owner_port[bank]!=1)$fatal(1,"MMacquiremissing");
  for(integer w=0;w<words;w++)begin
   if(w%3==0)begin mm2s_write_valid=0;tick();@(negedge aclk);end
   mm2s_write_bank=bank;mm2s_write_addr=32'(w);mm2s_write_data=input_words[int'(bank)*WORDS+w];mm2s_write_strb=16'hffff;mm2s_write_valid=1;
   if(!mm2s_write_ready)begin #1;if(!mm2s_write_ready)$fatal(1,"MMnotready");end
   tick();@(negedge aclk);
  end
  mm2s_write_valid=0;tick();@(negedge aclk);s_ctrl_mm2s_sts_valid=1;s_ctrl_mm2s_sts_bank=bank;s_ctrl_mm2s_sts_error=mm_clean_error;
  if(!m_ctrl_mm2s_sts_ready)$fatal(1,"MMstatusnotready");tick();@(negedge aclk);s_ctrl_mm2s_sts_valid=0;
 endtask
 task automatic ss_transfer;
  logic[4:0]bank;logic[86:0]held;integer words;
  bank=m_ctrl_s2mm_cmd_bank;held={m_ctrl_s2mm_cmd_addr,m_ctrl_s2mm_cmd_btt,m_ctrl_s2mm_cmd_offset,bank};words=int'(capacity_words(bank));
  if(bank<6 || m_ctrl_s2mm_cmd_btt!=32'(words*16) || m_ctrl_s2mm_cmd_offset!=0 || m_ctrl_s2mm_cmd_addr!==program_words[cmd_dispatcher_current_pc][31:0])$fatal(1,"SScommandfields");
  repeat(3)begin tick();if(!m_ctrl_s2mm_cmd_valid || {m_ctrl_s2mm_cmd_addr,m_ctrl_s2mm_cmd_btt,m_ctrl_s2mm_cmd_offset,m_ctrl_s2mm_cmd_bank}!==held || bank_busy!=0)$fatal(1,"SScommandstallchanged/acquired");end
  @(negedge aclk);m_ctrl_s2mm_cmd_ready=1;tick();@(negedge aclk);m_ctrl_s2mm_cmd_ready=0;
  ss_active=1;ss_bank=bank;ss_issued=0;ss_received=0;
  for(integer w=0;w<words;w++)begin
   if(w%5==0)begin s2mm_read_valid=0;tick();@(negedge aclk);end
   s2mm_read_valid=1;s2mm_read_bank=bank;s2mm_read_addr=32'(w);#1;if(!s2mm_read_ready)$fatal(1,"SSnotready");tick();@(negedge aclk);
  end
  s2mm_read_valid=0;
  while(ss_received<words)tick();tick();@(negedge aclk);ss_active=0;
  if(ss_issued!=words)$fatal(1,"SSreadcount");
  s_ctrl_s2mm_sts_valid=1;s_ctrl_s2mm_sts_bank=bank;tick();@(negedge aclk);s_ctrl_s2mm_sts_valid=0;
 endtask
 initial forever begin
  @(negedge aclk);
  if(aresetn&&auto_dma)begin
   if(m_ctrl_mm2s_cmd_valid)mm_transfer();
   else if(m_ctrl_s2mm_cmd_valid)ss_transfer();
  end
 end
 logic response_hold_done=0;
 initial begin
  wait(aresetn&&auto_dma&&dut.compute_cmd_valid&&dut.compute_cmd_ready);
  force dut.compute_resp_ready=0;
  wait(dut.compute_resp_valid);#1;
  if(cmd_dispatcher_error || dut.compute_resp_error || bank_busy==0 || dut.compute_resp_id!=saved_compute_id)$fatal(1,"responsehold phase not clean");
  repeat(4)begin tick();if(!dut.compute_resp_valid || dut.compute_resp_id!=saved_compute_id || dut.compute_resp_error || bank_busy==0 || (|dut.bank_release_valid))$fatal(1,"stalledcomputecompletion changed/released");end
  // XSIM variable-driver force release retains its value until RHS changes.
  // Restore the legally active controller ready for the acceptance edge first.
  @(negedge aclk);force dut.compute_resp_ready=1;tick();@(negedge aclk);release dut.compute_resp_ready;response_hold_done=1;
 end
 function automatic logic[127:0] instruction(input integer op,dst,src0,src1,desc,input logic[63:0]imm);
  return {8'(op),8'(dst),8'(src0),8'(src1),32'(desc),imm};
 endfunction
 task automatic reject(input logic[127:0]word,input integer code);
  integer old_acq,old_writes,old_physical;
  reset_dut();for(integer p=0;p<64;p++)program_words[p]=0;program_words[0]=word;
  old_acq=acquires;old_writes=mm_data_writes+compute_writes;old_physical=physical_writes+physical_reads;start_program();terminal(1,code);
  if(bank_busy || bank_valid || acquires!=old_acq || physical_writes+physical_reads!=old_physical || mm_data_writes+compute_writes!=old_writes || m_ctrl_mm2s_cmd_valid || m_ctrl_s2mm_cmd_valid || dut.compute_cmd_valid)$fatal(1,"illegalprogram touched bank");cases++;
 endtask
 // Real first-QUANTIZE completion/RELEASE fault regressions. No memory data,
 // ownership or ready signal is forced; only the isolated registered-error case
 // forces the router fault indication to model its delayed arrival at RELEASE.
 task automatic late_bank_fault(input integer phase,input integer kind);
  integer waited,old_writes,old_reads,old_releases;
  logic [18:0] expected_mask;
  reset_dut();for(integer p=0;p<64;p++)program_words[p]=0;
  for(integer p=0;p<21;p++)program_words[p]=canonical[p];
  auto_dma=1;start_program();waited=0;
  while((phase==0 && !dut.compute_resp_valid) || (phase==1 && !dut.bank_release_valid[6]))begin
   tick();waited++;if(waited>32000000)$fatal(1,"latebankfault phase timeout");
  end
  @(negedge aclk);
  expected_mask=19'd65;
  if(cmd_dispatcher_error || bank_error || pending0 || pending1 ||
     active_mask!==expected_mask || bank_busy!==expected_mask ||
     bank_owner_port[0]!=3 || bank_owner_port[6]!=5 || bank_valid[6] ||
     (phase==0 && (!dut.compute_resp_valid || dut.compute_resp_error || !dut.compute_resp_ready)) ||
     (phase==1 && dut.bank_release_valid!==expected_mask))$fatal(1,"latebankfault wrong phase");
  auto_dma=0;late_fault_active=1;
  old_writes=physical_writes;old_reads=physical_reads;old_releases=releases;
  if(kind==2)begin
   force dut.u_banks.router_error_w=1'b1;
  end else begin
   mm2s_write_valid=1;mm2s_write_bank=5'd6;
   mm2s_write_addr=(kind==1)?capacity_words(5'd6):32'd0;
   mm2s_write_data=128'hdeadbeef_deadbeef_deadbeef_deadbeef;mm2s_write_strb=16'hffff;
  end
  #1;
  if(!bank_error || (|dut.bank_release_accepted) || mm2s_write_ready ||
     dut.u_banks.mem_ena[6] || dut.u_banks.mem_enb[0])$fatal(1,"latebankfault immediate acceptance/touch");
  tick();@(negedge aclk);mm2s_write_valid=0;
  if(kind==2)release dut.u_banks.router_error_w;
  terminal(1,7);repeat(3)tick();
  if(physical_writes!=old_writes || physical_reads!=old_reads || releases!=old_releases ||
     active_mask!==expected_mask || bank_busy!==expected_mask || bank_owner_port[0]!=3 ||
     bank_owner_port[6]!=5 || bank_valid[6] || (|dut.bank_release_accepted))$fatal(1,"latebankfault released/committed/touched");
  $display("TENSOR_LATE_BANK_FAULT phase%0d kind%0d PASS",phase,kind);cases++;
  reset_dut();
 endtask
 initial begin
  tensor_desc_t d;integer cap,am,as,ac,aa,ar,late_index,late_writes;logic[31:0]saved_value;
  $readmemh("program.mem",canonical);$readmemh("diagnostic_program.mem",diagnostic);
  for(integer b=0;b<6;b++)begin cap=int'(capacity_words(5'(b)));$readmemh($sformatf("input_bank%02d.mem",b),input_words,b*WORDS,b*WORDS+cap-1);end
  for(integer b=6;b<19;b++)begin cap=int'(capacity_words(5'(b)));$readmemh($sformatf("expected_bank%02d.mem",b),golden_words,b*WORDS,b*WORDS+cap-1);end
  reset_dut();
  for(integer run=0;run<2;run++)begin
   for(integer p=0;p<64;p++)program_words[p]=0;
   if(run==0)for(integer p=0;p<21;p++)program_words[p]=canonical[p];
   else for(integer p=0;p<34;p++)program_words[p]=diagnostic[p];
   am=mm_count;as=ss_count;ac=compute_count;aa=acquires;ar=releases;
   auto_dma=1;$display("TENSOR_PROGRAM_START kind%0d latency%0d",run,CMD_READ_LATENCY);start_program();terminal(0,0);auto_dma=0;
   if(bank_valid!=19'h7ffff || mm_count-am!=6 || compute_count-ac!=13 || ss_count-as!=(run==0?1:14) || acquires-aa!=(run==0?20:33) || releases-ar!=(run==0?20:33))$fatal(1,"programcommand/validity counts");
   cases++;repeat(5)tick();
  end
  if(!response_hold_done)$fatal(1,"responsehold not covered");
  if(NEGATIVE_TESTS)begin
   reject(instruction(1,32,0,0,32,64'h10000000),2);
   reject(instruction(1,255,0,0,255,64'h10000000),2);
   reject(instruction(2,0,32,0,32,64'h10000000),2);
   reject(instruction(3,6,255,0,6,0),2);
   reject(instruction(3,0,0,0,0,0),2);
   reject(instruction(4,7,6,6,7,0),2);
   reject(instruction(1,0,1,0,0,64'h10000000),2);
   reject(instruction(1,0,0,0,32'h100,64'h10000000),2);
   reject(instruction(1,0,0,0,0,64'h110000000),2);
   reject(instruction(1,0,0,0,0,64'h10000001),2);
   reject(instruction(3,6,0,0,6,1),2);
   reject(instruction(1,0,0,0,0,64'hfffffff0),3);
   reject(instruction(2,0,18,0,18,64'hfffffff0),3);
   reject(instruction(0,1,0,0,0,0),2);
   reject(instruction(8,0,0,0,0,0),1);
   reject(instruction(3,6,1,0,6,0),3);
   reject(instruction(3,6,0,0,6,0),4);
   reject(instruction(2,0,18,0,18,64'h20000000),4);
   // Missing END reaches the bounded command BRAM limit after clean MM completions.
   reset_dut();for(integer p=0;p<64;p++)program_words[p]=canonical[0];auto_dma=1;start_program();terminal(1,9);auto_dma=0;
   if(bank_busy || !bank_valid[0])$fatal(1,"missingEND didnotdrain");cases++;
   // A DMA extent ending exactly at 2^32 is legal, without address wrapping.
   reset_dut();program_words[0]=instruction(1,0,0,0,0,64'h100000000-64'(capacity_words(0)*16));program_words[1]=0;
   auto_dma=1;start_program();terminal(0,0);auto_dma=0;if(bank_busy || bank_valid!=19'd1)$fatal(1,"legalDDRendboundary");cases++;
   // Wrong full five-bit DMA completion bank cannot release the real owner.
   for(integer bad=0;bad<2;bad++)begin
    reset_dut();program_words[0]=canonical[0];program_words[1]=0;start_program();
    while(!m_ctrl_mm2s_cmd_valid)tick();
    if(cmd_dispatcher_error || bank_busy!=0)$fatal(1,"wrongstatusprecondition");
    @(negedge aclk);m_ctrl_mm2s_cmd_ready=1;tick();@(negedge aclk);m_ctrl_mm2s_cmd_ready=0;
    if(bank_owner_port[0]!=1 || !bank_busy[0])$fatal(1,"wrongstatusownerphase");
    s_ctrl_mm2s_sts_valid=1;s_ctrl_mm2s_sts_bank=bad==0?5'd1:5'd31;tick();@(negedge aclk);s_ctrl_mm2s_sts_valid=0;
    terminal(1,5);if(!bank_busy[0] || bank_owner_port[0]!=1 || bank_valid[0])$fatal(1,"wrongstatusreleased/committed");cases++;
   end
   // Duplicate completion is never accepted as a second retirement.
   reset_dut();program_words[0]=canonical[0];program_words[1]=0;start_program();while(!m_ctrl_mm2s_cmd_valid)tick();mm_transfer();
   if(cmd_dispatcher_error)$fatal(1,"duplicate precondition alreadyfaulted");
   s_ctrl_mm2s_sts_valid=1;s_ctrl_mm2s_sts_bank=0;tick();@(negedge aclk);s_ctrl_mm2s_sts_valid=0;terminal(1,5);
   if(active_mask!=0 && !bank_busy[0])$fatal(1,"duplicate unrelated retirement");cases++;
   // Clean engine error follows every accepted write, releases, and never commits.
   reset_dut();program_words[0]=canonical[0];program_words[1]=0;mm_clean_error=1;auto_dma=1;start_program();terminal(1,6);auto_dma=0;
   if(bank_busy || bank_valid[0])$fatal(1,"cleanDMAerror release/commit");cases++;
   // An unclean fault while a command is stalled preserves valid and payload.
   reset_dut();program_words[0]=canonical[0];program_words[1]=0;start_program();while(!m_ctrl_mm2s_cmd_valid)tick();
   if(cmd_dispatcher_error || bank_busy!=0)$fatal(1,"stallfaultphase");
   @(negedge aclk);s_ctrl_mm2s_faulted=1;
   repeat(4)begin tick();if(!m_ctrl_mm2s_cmd_valid || m_ctrl_mm2s_cmd_bank!=0 || m_ctrl_mm2s_cmd_addr!=canonical[0][31:0] || bank_busy!=0)$fatal(1,"faultretractedstalledcommand");end
   @(negedge aclk);m_ctrl_mm2s_cmd_ready=1;tick();@(negedge aclk);m_ctrl_mm2s_cmd_ready=0;terminal(1,5);
   if(!bank_busy[0] || bank_owner_port[0]!=1)$fatal(1,"uncleanfaultownershiplost");cases++;
   // A late-row NaN occurs after earlier accepted output words; it invalidates
   // publication while permitting physical earlier words to remain in memory.
   reset_dut();d=get_descriptor(0);late_index=int'((d.dim0-1)*d.dim1);
   saved_value=input_words[late_index/4][32*(late_index%4)+:32];input_words[late_index/4][32*(late_index%4)+:32]=32'h7fc01234;
   program_words[0]=canonical[0];program_words[1]=canonical[6];program_words[2]=instruction(2,0,6,0,6,64'h20000000);program_words[3]=0;
   late_writes=compute_writes;as=ss_count;auto_dma=1;start_program();terminal(1,4);auto_dma=0;
   input_words[late_index/4][32*(late_index%4)+:32]=saved_value;
   if(bank_busy || bank_valid[6] || !bank_valid[0] || compute_writes-late_writes<=int'(capacity_words(6)) || ss_count!=as)$fatal(1,"latefault commit/drain/phase");cases++;
   // Corrupt a real, clean compute completion identity only at its valid phase.
   reset_dut();for(integer p=0;p<21;p++)program_words[p]=canonical[p];auto_dma=1;start_program();
   while(!dut.compute_resp_valid)tick();
   if(cmd_dispatcher_error || dut.compute_resp_error || dut.compute_resp_id!=saved_compute_id || pending0 || pending1 || !bank_busy[0] || !bank_busy[6])$fatal(1,"computeidentity injectionphase");
   force dut.compute_resp_id=16'hffff;tick();@(negedge aclk);release dut.compute_resp_id;terminal(1,5);auto_dma=0;
   if(!bank_busy[0] || !bank_busy[6] || bank_owner_port[0]!=3 || bank_owner_port[6]!=5 || bank_valid[6])$fatal(1,"badcomputeidentity released/committed");cases++;
   // Coordinated reset in actual compute read flight; cancellation and fresh restart.
   for(integer phase=0;phase<2;phase++)for(integer kind=0;kind<2;kind++)late_bank_fault(phase,kind);
   late_bank_fault(1,2);
   reset_dut();for(integer p=0;p<21;p++)program_words[p]=canonical[p];auto_dma=1;start_program();
   while(pending0==0)tick();if(cmd_dispatcher_error || bank_busy==0)$fatal(1,"resetreadphase");reset_dut();repeat(10)tick();if(cmd_dispatcher_busy || dut.compute_resp_valid || bank_busy || bank_valid)$fatal(1,"resetreadcancellation");cases++;
   for(integer p=0;p<21;p++)program_words[p]=canonical[p];auto_dma=1;start_program();terminal(0,0);auto_dma=0;cases++;
  end
  $display("ATTENTION_TENSOR_ISA_CASES=%0d mm=%0d compute=%0d ss=%0d cycles=%0d",cases,mm_count,compute_count,ss_count,cycle);
  $display("ATTENTION_TENSOR_ISA_XSIM_PASS");$finish;
 end
 initial begin #2000000000;$fatal(1,"globaltimeout PC%0d ctl%0d exe%0d",cmd_dispatcher_current_pc,dut.u_controller.state_r,dut.u_executor.state_r);end
endmodule
