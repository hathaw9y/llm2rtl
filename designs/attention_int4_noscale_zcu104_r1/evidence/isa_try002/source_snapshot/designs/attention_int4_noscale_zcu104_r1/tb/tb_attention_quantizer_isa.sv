`timescale 1ns/1ps
module tb_attention_quantizer_isa #(parameter integer ROW_COUNT=29, BAD_COUNT=9);
  localparam integer CMD_ADDR_WIDTH=6,CMD_DATA_WIDTH=128;
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

  logic mm2s_bank_ena[0:2];logic[31:0]mm2s_bank_addra[0:2];logic[127:0]mm2s_bank_dina[0:2];logic[15:0]mm2s_bank_wea[0:2];wire mm2s_bank_ready[0:2];
  logic s2mm_bank_enb[0:2];logic[31:0]s2mm_bank_addrb[0:2];wire[127:0]s2mm_bank_doutb[0:2];wire s2mm_bank_read_ready[0:2],s2mm_bank_valid[0:2];
  wire bank_subsystem_error;wire[2:0]bank_subsystem_error_code;
  attention_quantizer_isa_top #(.CMD_ADDR_WIDTH(CMD_ADDR_WIDTH),.MAX_COMMANDS(64))dut(.*);
  logic[127:0]command_mem[0:63],cmd_pipe[0:1],programs[0:ROW_COUNT*5-1];
  logic[127:0]source_words[0:ROW_COUNT*64-1],quant_words[0:ROW_COUNT*8-1],bad_commands[0:BAD_COUNT-1];logic[31:0]metadata[0:ROW_COUNT-1];
  assign cmd_doutb=cmd_pipe[1];
  integer row=0,elements=0,src_reads=0,data_writes=0,scale_writes=0,quant_acquires=0,quant_releases=0,mm_commands=0,ss_commands=0,cases=0;
  logic row_error=0,check_quant=0;logic[15:0]expected_scale=0;
  logic[127:0]read_expected[0:3];logic read_expected_valid[0:3];integer read_bank=0,read_count=0;
  always @(posedge aclk)begin
    if(!aresetn)begin
      cmd_pipe[0]<=0;cmd_pipe[1]<=0;src_reads=0;data_writes=0;scale_writes=0;quant_acquires=0;quant_releases=0;mm_commands=0;ss_commands=0;read_count=0;
      for(integer p=0;p<4;p++)read_expected_valid[p]=0;
    end else begin
      if(cmd_enb)cmd_pipe[0]<=command_mem[cmd_addrb];cmd_pipe[1]<=cmd_pipe[0];
      if(m_ctrl_mm2s_cmd_valid&&m_ctrl_mm2s_cmd_ready)begin
        if(m_ctrl_mm2s_cmd_bank!=0||m_ctrl_mm2s_cmd_tag!=0||!dut.u_banks.bank_wr_busy[0]||dut.u_banks.bank_wr_owner_port[0]!=1)$fatal(1,"DMA MM issue before owner/tag");mm_commands++;
      end
      if(m_ctrl_s2mm_cmd_valid&&m_ctrl_s2mm_cmd_ready)begin
        if(!dut.u_banks.bank_rd_busy[m_ctrl_s2mm_cmd_bank]||dut.u_banks.bank_rd_owner_port[m_ctrl_s2mm_cmd_bank]!=2||m_ctrl_s2mm_cmd_tag!={2'b0,m_ctrl_s2mm_cmd_bank})$fatal(1,"DMA S issue before owner/tag");ss_commands++;
      end
      if(dut.u_controller.bank_rd_acquire_valid[0]&&dut.u_controller.bank_rd_acquire_port[0]==3)begin
        if(dut.u_controller.bank_rd_acquire_valid!=3'b001||dut.u_controller.bank_wr_acquire_valid!=3'b110||dut.u_controller.bank_wr_acquire_port[1]!=4||dut.u_controller.bank_wr_acquire_port[2]!=5||dut.u_controller.bank_rd_acquire_accepted!=3'b001||dut.u_controller.bank_wr_acquire_accepted!=3'b110)$fatal(1,"quant 3-role acquire not atomic");quant_acquires++;
      end
      if(dut.u_executor.cmd_valid)begin
        if(!dut.u_banks.bank_rd_busy[0]||dut.u_banks.bank_rd_owner_port[0]!=3||dut.u_banks.bank_wr_busy[2:1]!=2'b11||dut.u_banks.bank_wr_owner_port[1]!=4||dut.u_banks.bank_wr_owner_port[2]!=5)$fatal(1,"executor valid before all owners");
      end
      if(dut.u_executor.quant_src_bank_enb[0]&&dut.u_executor.quant_src_bank_read_ready[0])begin
        if(dut.u_executor.quant_src_bank_addrb[0]!=src_reads)$fatal(1,"source read sequence");src_reads++;
      end
      if(dut.u_executor.quant_data_bank_ena[1]&&dut.u_executor.quant_data_bank_ready[1])begin
        if(!check_quant||row_error||dut.u_executor.quant_data_bank_addra[1]!=data_writes||dut.u_executor.quant_data_bank_wea[1]!=16'hffff||dut.u_executor.quant_data_bank_dina[1]!==quant_words[row*8+data_writes])$fatal(1,"packed data write/tail mismatch row%0d word%0d got%h exp%h",row,data_writes,dut.u_executor.quant_data_bank_dina[1],quant_words[row*8+data_writes]);data_writes++;
      end
      if(dut.u_executor.quant_scale_bank_ena[2]&&dut.u_executor.quant_scale_bank_ready[2])begin
        if(!check_quant||row_error||dut.u_executor.quant_scale_bank_addra[2]!=0||dut.u_executor.quant_scale_bank_wea[2]!=16'hffff||dut.u_executor.quant_scale_bank_dina[2]!=={112'b0,expected_scale}||data_writes!=(elements+31)/32)$fatal(1,"scale write/ordering mismatch");scale_writes++;
      end
      if(dut.u_controller.bank_rd_release_valid[0]&&dut.u_controller.bank_rd_release_port[0]==3)begin
        if(dut.u_controller.bank_rd_release_valid!=3'b001||dut.u_controller.bank_wr_release_valid!=3'b110||dut.u_controller.bank_wr_release_port[1]!=4||dut.u_controller.bank_wr_release_port[2]!=5||dut.u_controller.bank_rd_release_accepted!=3'b001||dut.u_controller.bank_wr_release_accepted!=3'b110)$fatal(1,"quant release roles/atomicity");
        if(src_reads!=(elements+3)/4||data_writes!=(row_error?0:(elements+31)/32)||scale_writes!=(row_error?0:1))$fatal(1,"quant release before final payload consumption/acceptance");quant_releases++;
      end
      if(dut.u_executor.resp_valid && (!check_quant||src_reads!=(elements+3)/4||data_writes!=(row_error?0:(elements+31)/32)||scale_writes!=(row_error?0:1)))$fatal(1,"executor completion before memory completion");
      if(cmd_dispatcher_done&&(dut.u_banks.bank_wr_busy||dut.u_banks.bank_rd_busy))$fatal(1,"END before ownership drain");
      for(integer p=3;p>0;p--)begin read_expected_valid[p]=read_expected_valid[p-1];read_expected[p]=read_expected[p-1];end
      read_expected_valid[0]=s2mm_bank_enb[read_bank]&&s2mm_bank_read_ready[read_bank];
      if(read_expected_valid[0])read_expected[0]=(read_bank==1)?quant_words[row*8+s2mm_bank_addrb[read_bank]]:{112'b0,expected_scale};
    end
    #1;
    if(aresetn)begin
      if(s2mm_bank_valid[read_bank]!==read_expected_valid[3])$fatal(1,"DMA response latency");
      if(read_expected_valid[3])begin if(s2mm_bank_doutb[read_bank]!==read_expected[3])$fatal(1,"ISA DMA roundtrip data/scale mismatch row%0d bank%0d",row,read_bank);read_count++;end
    end
  end
  task automatic tick;@(posedge aclk);#1.1;@(negedge aclk);endtask
  task automatic clear_ports;
    cmd_dispatcher_start=0;m_ctrl_mm2s_cmd_ready=0;m_ctrl_s2mm_cmd_ready=0;s_ctrl_mm2s_sts_valid=0;s_ctrl_s2mm_sts_valid=0;s_ctrl_mm2s_sts_error=0;s_ctrl_s2mm_sts_error=0;
    for(integer b=0;b<3;b++)begin mm2s_bank_ena[b]=0;mm2s_bank_addra[b]=0;mm2s_bank_dina[b]=0;mm2s_bank_wea[b]=0;s2mm_bank_enb[b]=0;s2mm_bank_addrb[b]=0;end
  endtask
  task automatic reset_dut;
    @(negedge aclk);aresetn=0;clear_ports();check_quant=0;release dut.u_executor.cmd_ready;release dut.u_executor.quant_src_bank_read_ready[0];release dut.u_executor.quant_data_bank_ready[1];release dut.u_executor.quant_scale_bank_ready[2];
    repeat(3)tick();aresetn=1;tick();
    if(cmd_dispatcher_busy||cmd_dispatcher_done||cmd_dispatcher_error||bank_subsystem_error||dut.u_banks.bank_wr_busy||dut.u_banks.bank_rd_busy)$fatal(1,"ISA reset state");
    for(integer pc=0;pc<64;pc++)command_mem[pc]=0;
  endtask
  task automatic start_row(input integer index);
    src_reads=0;data_writes=0;scale_writes=0;quant_acquires=0;quant_releases=0;mm_commands=0;ss_commands=0;read_count=0;
    row=index;elements=metadata[row]>>17;row_error=metadata[row][16];expected_scale=metadata[row][15:0];check_quant=1;
    for(integer pc=0;pc<5;pc++)command_mem[pc]=programs[row*5+pc];
    cmd_dispatcher_start=1;tick();cmd_dispatcher_start=0;
  endtask
  task automatic dma_mm;
    while(!m_ctrl_mm2s_cmd_valid)tick();
    repeat(3)begin if(!m_ctrl_mm2s_cmd_valid||m_ctrl_mm2s_cmd_bank!=0||m_ctrl_mm2s_cmd_addr!=32'h1000||m_ctrl_mm2s_cmd_btt!=((elements+3)/4)*16||m_ctrl_mm2s_cmd_offset!=0)$fatal(1,"MM command unstable/payload");tick();end
    m_ctrl_mm2s_cmd_ready=1;tick();m_ctrl_mm2s_cmd_ready=0;
    for(integer word_idx=0;word_idx<(elements+3)/4;word_idx++)begin
      mm2s_bank_ena[0]=1;mm2s_bank_addra[0]=word_idx;mm2s_bank_dina[0]=source_words[row*64+word_idx];mm2s_bank_wea[0]='1;
      while(!mm2s_bank_ready[0])tick();tick();mm2s_bank_ena[0]=0;if(word_idx%3==0)tick();
    end
    s_ctrl_mm2s_sts_tag=0;s_ctrl_mm2s_sts_valid=1;while(!m_ctrl_mm2s_sts_ready)tick();tick();s_ctrl_mm2s_sts_valid=0;
  endtask
  task automatic dma_ss(input integer bank,input integer words);
    integer before_count;
    while(!m_ctrl_s2mm_cmd_valid)tick();
    repeat(3)begin if(!m_ctrl_s2mm_cmd_valid||m_ctrl_s2mm_cmd_bank!=bank||m_ctrl_s2mm_cmd_btt!=words*16||m_ctrl_s2mm_cmd_offset!=0||m_ctrl_s2mm_cmd_addr!=(bank==1?32'h2000:32'h3000))$fatal(1,"S command unstable/payload");tick();end
    m_ctrl_s2mm_cmd_ready=1;tick();m_ctrl_s2mm_cmd_ready=0;read_bank=bank;before_count=read_count;
    for(integer word_idx=0;word_idx<words;word_idx++)begin
      s2mm_bank_enb[bank]=1;s2mm_bank_addrb[bank]=word_idx;while(!s2mm_bank_read_ready[bank])tick();tick();s2mm_bank_enb[bank]=0;
      if(word_idx%3==0)tick();
    end
    while(read_count!=before_count+words)tick();tick(); // Sink consumes last response before completion.
    s_ctrl_s2mm_sts_tag=4'(bank);s_ctrl_s2mm_sts_valid=1;while(!m_ctrl_s2mm_sts_ready)tick();tick();s_ctrl_s2mm_sts_valid=0;
    repeat(3)tick();
  endtask
  task automatic terminal(input bit error,input integer code);
    integer n;n=0;while(cmd_dispatcher_busy&&n<300)begin tick();n++;end
    if(cmd_dispatcher_busy||cmd_dispatcher_error!==error||(error&&cmd_dispatcher_error_code!=code)||(!error&&!cmd_dispatcher_done)||dut.u_banks.bank_wr_busy||dut.u_banks.bank_rd_busy||bank_subsystem_error)$fatal(1,"ISA terminal/error/drain mismatch code%0d expected%0d",cmd_dispatcher_error_code,code);
  endtask
  initial begin
    $readmemh("isa_inputs.hex",source_words,0,ROW_COUNT*64-1);$readmemh("isa_outputs.hex",quant_words,0,ROW_COUNT*8-1);$readmemh("isa_metadata.hex",metadata,0,ROW_COUNT-1);$readmemh("isa_programs.hex",programs,0,ROW_COUNT*5-1);$readmemh("isa_bad_programs.hex",bad_commands,0,BAD_COUNT-1);
    for(integer index=0;index<ROW_COUNT;index++)begin
      if(index==0||metadata[index-1][16])reset_dut();else begin clear_ports();if(dut.u_banks.bank_wr_busy||dut.u_banks.bank_rd_busy)$fatal(1,"sequential reuse before drain");end
      force dut.u_executor.cmd_ready=0;force dut.u_executor.quant_src_bank_read_ready[0]=0;
      force dut.u_executor.quant_data_bank_ready[1]=0;force dut.u_executor.quant_scale_bank_ready[2]=0;
      $display("ISA_ROW_START=%0d elements=%0d",index,metadata[index]>>17);start_row(index);dma_mm();$display("ISA_MM_DONE row%0d pc%0d",row,current_pc);while(!dut.u_executor.cmd_valid)tick();
      repeat(4)begin if(!dut.u_executor.cmd_valid||dut.u_executor.resp_valid||src_reads)$fatal(1,"compute stalled-command contract");tick();end
      release dut.u_executor.cmd_ready;tick();repeat(4)begin if(src_reads||dut.u_executor.resp_valid)$fatal(1,"source ready stall not honored");tick();end;release dut.u_executor.quant_src_bank_read_ready[0];
      if(row_error)begin
        release dut.u_executor.quant_data_bank_ready[1];release dut.u_executor.quant_scale_bank_ready[2];terminal(1,4);
        if(data_writes||scale_writes||ss_commands||quant_acquires!=1||quant_releases!=1)$fatal(1,"nonfinite ISA side effects");
      end else begin
        repeat(elements*4+100)begin if(data_writes||scale_writes||dut.u_executor.resp_valid||quant_releases)$fatal(1,"write stall bypass or premature completion");tick();end
        release dut.u_executor.quant_data_bank_ready[1];while(data_writes!=(elements+31)/32)tick();
        repeat(5)begin if(scale_writes||dut.u_executor.resp_valid||quant_releases)$fatal(1,"completion before scale write acceptance");tick();end
        release dut.u_executor.quant_scale_bank_ready[2];dma_ss(1,(elements+31)/32);dma_ss(2,1);terminal(0,0);
        if(mm_commands!=1||ss_commands!=2||quant_acquires!=1||quant_releases!=1)$fatal(1,"ISA exact issue/release count");
      end
      cases++;
    end
    // Two different rows/scales reuse all three banks within one uninterrupted
    // nine-instruction program, with a single END after both DMA roundtrips.
    reset_dut();start_row(0);
    for(integer pc=0;pc<4;pc++)command_mem[pc+4]=programs[4*5+pc];command_mem[8]=0;
    dma_mm();dma_ss(1,1);dma_ss(2,1);
    if(quant_acquires!=1||quant_releases!=1||cmd_dispatcher_done)$fatal(1,"first row did not remain in combined program");
    row=4;elements=metadata[row]>>17;row_error=metadata[row][16];expected_scale=metadata[row][15:0];
    src_reads=0;data_writes=0;scale_writes=0;quant_acquires=0;quant_releases=0;mm_commands=0;ss_commands=0;read_count=0;
    dma_mm();dma_ss(1,(elements+31)/32);dma_ss(2,1);terminal(0,0);
    if(quant_acquires!=1||quant_releases!=1||current_pc!=8)$fatal(1,"second row/END in combined program");cases++;
    // Alias/count/range/address and unsupported opcode reject before ownership.
    for(integer bad=0;bad<BAD_COUNT;bad++)begin reset_dut();command_mem[0]=bad_commands[bad];cmd_dispatcher_start=1;tick();cmd_dispatcher_start=0;terminal(1,bad==BAD_COUNT-1?1:2);
      if(mm_commands||ss_commands||quant_acquires||quant_releases||src_reads||data_writes||scale_writes)$fatal(1,"illegal ISA touched payload/ownership");cases++;end
    // Full four-bit DMA tags must be range-checked before any narrowed index.
    // Tag4 would alias bank0 if a cast accidentally replaced the range check.
    for(integer bad_tag=0;bad_tag<2;bad_tag++)begin
      reset_dut();start_row(0);while(!m_ctrl_mm2s_cmd_valid)tick();m_ctrl_mm2s_cmd_ready=1;tick();m_ctrl_mm2s_cmd_ready=0;
      s_ctrl_mm2s_sts_tag=bad_tag==0?4'h4:4'hf;s_ctrl_mm2s_sts_valid=1;tick();s_ctrl_mm2s_sts_valid=0;
      while(!cmd_dispatcher_error)tick();repeat(4)tick();
      if(cmd_dispatcher_error_code!=3||dut.u_banks.bank_wr_busy!=3'b001||dut.u_banks.bank_wr_owner_port[0]!=1||dut.u_banks.bank_rd_busy||quant_acquires||quant_releases||src_reads||data_writes||scale_writes)$fatal(1,"invalid full DMA tag aliased/released owner");cases++;
    end
    // Reset while source requests and while an output is held in write stall.
    reset_dut();force dut.u_executor.quant_src_bank_read_ready[0]=0;start_row(1);dma_mm();repeat(15)tick();reset_dut();repeat(8)tick();if(cmd_dispatcher_done||cmd_dispatcher_error)$fatal(1,"reset read cancellation");cases++;
    reset_dut();force dut.u_executor.quant_data_bank_ready[1]=0;start_row(1);dma_mm();repeat(elements*4+100)tick();reset_dut();repeat(8)tick();if(cmd_dispatcher_done||cmd_dispatcher_error)$fatal(1,"reset write cancellation");cases++;
    $display("QUANTIZER_ISA_CASES=%0d rows=%0d",cases,ROW_COUNT);
    $display("ATTENTION_QUANTIZER_ISA_XSIM_PASS");$finish;
  end
  initial begin #20000000;$fatal(1,"ISA timeout row%0d pc%0d ctlstate%0d execstate%0d cmdv%0b cmdr%0b srcreads%0d datawrites%0d scalewrites%0d bankwr%0b bankrd%0b error%0d",row,current_pc,dut.u_controller.state_r,dut.u_executor.state_r,dut.u_executor.cmd_valid,dut.u_executor.cmd_ready,src_reads,data_writes,scale_writes,dut.u_banks.bank_wr_busy,dut.u_banks.bank_rd_busy,cmd_dispatcher_error_code);end
endmodule
