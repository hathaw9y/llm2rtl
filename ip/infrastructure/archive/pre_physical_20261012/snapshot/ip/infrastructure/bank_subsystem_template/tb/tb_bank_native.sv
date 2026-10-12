`timescale 1ns/1ps
module tb_bank_native;
  import native_test_config_pkg::*;
  logic aclk=0, aresetn=0;
  always #2.5 aclk=~aclk;
  logic [1:0] bank_wr_acquire_valid,bank_rd_acquire_valid,bank_wr_release_valid,bank_rd_release_valid;
  logic [1:0][2:0] bank_wr_acquire_port,bank_rd_acquire_port,bank_wr_release_port,bank_rd_release_port;
  wire [1:0] bank_wr_busy,bank_rd_busy;
  wire [1:0][2:0] bank_wr_owner_port,bank_rd_owner_port;
  logic mm2s_bank_ena[0:1]; logic [31:0] mm2s_bank_addra[0:1];
  logic [127:0] mm2s_bank_dina[0:1]; logic [15:0] mm2s_bank_wea[0:1]; wire mm2s_bank_ready[0:1];
  logic s2mm_bank_enb[0:1]; logic [31:0] s2mm_bank_addrb[0:1];
  wire [127:0] s2mm_bank_doutb[0:1]; wire s2mm_bank_read_ready[0:1],s2mm_bank_valid[0:1];
  wire [1:0][32:0] bank_committed_prefix;
  wire bank_subsystem_error,ownership_error,router_error;
  wire [2:0] bank_subsystem_error_code,ownership_error_code,router_error_code;
  wire[1:0]bank_wr_acquire_accepted,bank_rd_acquire_accepted,bank_wr_release_accepted,bank_rd_release_accepted;
  native_test_bank_subsystem dut(.*);
  logic [127:0] model[0:1][0:4095];
  logic expect_valid[0:1][0:3]; logic [127:0] expect_data[0:1][0:3];
  integer responses=0, accepted_reads=0, cases=0;
  logic completion_release_latched=0; logic[2:0]outstanding_reader=0;
  always @(posedge aclk) begin
    if(!aresetn) begin
      for(integer b=0;b<2;b++) for(integer s=0;s<4;s++) expect_valid[b][s]=0;
    end else begin
      for(integer b=0;b<2;b++) begin
        for(integer s=3;s>0;s--) begin expect_valid[b][s]=expect_valid[b][s-1];expect_data[b][s]=expect_data[b][s-1];end
        if(mm2s_bank_ena[b] && mm2s_bank_ready[b])
          for(integer byte_idx=0;byte_idx<16;byte_idx++)
            if(mm2s_bank_wea[b][byte_idx]) model[b][mm2s_bank_addra[b]][byte_idx*8+:8]=mm2s_bank_dina[b][byte_idx*8+:8];
        expect_valid[b][0]=s2mm_bank_enb[b] && s2mm_bank_read_ready[b];
        if(expect_valid[b][0]) begin expect_data[b][0]=model[b][s2mm_bank_addrb[b]];accepted_reads++;end
      end
    end
    #1;
    for(integer b=0;b<2;b++) begin
      if(s2mm_bank_valid[b] !== expect_valid[b][3]) $fatal(1,"latency/valid bank%0d got%0b expected%0b",b,s2mm_bank_valid[b],expect_valid[b][3]);
      if(expect_valid[b][3]) begin
        if(s2mm_bank_doutb[b] !== expect_data[b][3]) $fatal(1,"payload bank%0d got%h expected%h",b,s2mm_bank_doutb[b],expect_data[b][3]);
        responses++;
      end
    end
  end
  task automatic idle;
    bank_wr_acquire_valid=0;bank_rd_acquire_valid=0;bank_wr_release_valid=0;bank_rd_release_valid=0;
    bank_wr_acquire_port=0;bank_rd_acquire_port=0;bank_wr_release_port=0;bank_rd_release_port=0;
    for(integer b=0;b<2;b++) begin mm2s_bank_ena[b]=0;mm2s_bank_addra[b]=0;mm2s_bank_dina[b]=0;mm2s_bank_wea[b]=0;s2mm_bank_enb[b]=0;s2mm_bank_addrb[b]=0;end
  endtask
  task automatic tick; @(posedge aclk);#1.1;@(negedge aclk);endtask
  task automatic reset_dut; @(negedge aclk);aresetn=0;idle();repeat(3)tick();aresetn=1;tick();
    if(bank_wr_busy||bank_rd_busy||bank_subsystem_error||bank_committed_prefix) $fatal(1,"reset state");endtask
  task automatic acquire_all;
    bank_wr_acquire_valid=3;bank_rd_acquire_valid=3;bank_wr_acquire_port='{3'd1,3'd1};bank_rd_acquire_port='{3'd2,3'd2};#0.1;
    if(bank_wr_acquire_accepted!=3||bank_rd_acquire_accepted!=3)$fatal(1,"acquire acceptance pulse");tick();idle();
    if(bank_wr_busy!=3||bank_rd_busy!=3) $fatal(1,"split acquisition");endtask
  task automatic write_word(input integer b,input integer addr,input logic[127:0]data,input logic[15:0]strb);
    mm2s_bank_ena[b]=1;mm2s_bank_addra[b]=addr;mm2s_bank_dina[b]=data;mm2s_bank_wea[b]=strb;
    #0.1;if(!mm2s_bank_ready[b]) $fatal(1,"write not ready");tick();mm2s_bank_ena[b]=0;endtask
  task automatic read_word(input integer b,input integer addr);
    s2mm_bank_enb[b]=1;s2mm_bank_addrb[b]=addr;#0.1;if(!s2mm_bank_read_ready[b])$fatal(1,"read not ready");tick();s2mm_bank_enb[b]=0;repeat(4)tick();endtask
  initial begin
    idle();reset_dut();cases++;
    // A legal write and illegal reader acquisition reject both directions atomically.
    bank_wr_acquire_valid=1;bank_wr_acquire_port[0]=1;bank_rd_acquire_valid=2;bank_rd_acquire_port[1]=1;
    tick();idle();if(bank_wr_busy||bank_rd_busy||!ownership_error)$fatal(1,"cross direction capability atomicity");cases++;
    reset_dut();acquire_all();
    // Conflict on one bank must also reject the other request.
    bank_wr_release_valid=2;bank_wr_release_port[1]=1;tick();idle();
    bank_wr_acquire_valid=3;bank_wr_acquire_port='{3'd1,3'd1};tick();idle();
    if(bank_wr_busy!=1||!ownership_error)$fatal(1,"acquire conflict atomicity");cases++;
    reset_dut();acquire_all();
    bank_wr_release_valid=3;bank_wr_release_port='{3'd2,3'd1};tick();idle();
    if(bank_wr_busy!=3||!ownership_error)$fatal(1,"wrong-owner release atomicity");cases++;
    reset_dut();
    bank_wr_acquire_valid=1;bank_wr_acquire_port[0]=1;bank_wr_release_valid=1;bank_wr_release_port[0]=1;tick();idle();
    if(bank_wr_busy||!ownership_error)$fatal(1,"overlap reject");cases++;
    reset_dut();acquire_all();
    for(integer b=0;b<2;b++) begin
      for(integer addr=0;addr<8;addr++)write_word(b,addr,128'h112233445566778899aabbccddeeff00+addr+b*32,16'hffff);
      if(bank_committed_prefix[b]!=8)$fatal(1,"sequential prefix");
      write_word(b,10,128'hffff,16'hffff);write_word(b,8,128'h1234,16'h0001);
      if(bank_committed_prefix[b]!=8)$fatal(1,"gap/partial prefix");
      write_word(b,8,128'h12345678,16'hffff);if(bank_committed_prefix[b]!=9)$fatal(1,"prefix recovery");
    end
    cases++;
    // Consecutive requests to both memory types prove II=1 and latency four.
    for(integer addr=0;addr<8;addr++) begin
      for(integer b=0;b<2;b++)begin s2mm_bank_enb[b]=1;s2mm_bank_addrb[b]=addr;end
      tick();
    end
    for(integer b=0;b<2;b++)s2mm_bank_enb[b]=0;
    repeat(5)tick();cases++;
    // DMA writing bank1 while reading bank0, then opposite directions.
    for(integer b=0;b<2;b++) begin
      mm2s_bank_ena[b]=1;mm2s_bank_addra[b]=12;mm2s_bank_dina[b]=128'habcdef+b;mm2s_bank_wea[b]='1;
      s2mm_bank_enb[1-b]=1;s2mm_bank_addrb[1-b]=2;tick();idle();repeat(5)tick();read_word(b,12);
    end
    // Same native edge write+read; read address pipeline sees the preceding write.
    mm2s_bank_ena[0]=1;mm2s_bank_addra[0]=13;mm2s_bank_dina[0]=128'hfedcba;mm2s_bank_wea[0]='1;
    s2mm_bank_enb[0]=1;s2mm_bank_addrb[0]=13;tick();idle();repeat(5)tick();cases++;
    // Engine consumes its response before presenting release. Cross-direction
    // release remains atomic on an illegal owner in either direction.
    read_word(0,0);bank_rd_release_valid=1;bank_rd_release_port[0]=2;
    bank_wr_release_valid=2;bank_wr_release_port[1]=2;tick();idle();
    if(!bank_rd_busy[0]||!bank_wr_busy[1]||!ownership_error)$fatal(1,"cross-direction release owner atomicity");
    bank_rd_release_valid=1;bank_rd_release_port[0]=2;tick();idle();if(bank_rd_busy[0])$fatal(1,"engine-completed release");cases++;
    // Bad addresses must not alias zero or return a response.
    s2mm_bank_enb[1]=1;s2mm_bank_addrb[1]=4096;mm2s_bank_ena[0]=1;mm2s_bank_addra[0]=64;mm2s_bank_dina[0]='1;mm2s_bank_wea[0]='1;
    #0.1;if(s2mm_bank_read_ready[1]||mm2s_bank_ready[0])$fatal(1,"bad address accepted");tick();idle();repeat(5)tick();
    if(!router_error)$fatal(1,"range error absent");bank_rd_acquire_valid=1;bank_rd_acquire_port[0]=2;tick();idle();read_word(0,0);cases++;
    // The engine produces completion only after consuming memory resp_valid.
    s2mm_bank_enb[0]=1;s2mm_bank_addrb[0]=1;tick();s2mm_bank_enb[0]=0;
    outstanding_reader=2;completion_release_latched=0;
    while(!s2mm_bank_valid[0])begin
      if(bank_rd_release_valid[0]||!bank_rd_busy[0]||completion_release_latched)$fatal(1,"ownership released before engine read completion");tick();
    end
    tick(); // The sink clock consumes/processes the last visible response.
    completion_release_latched=1;
    bank_rd_release_valid=1;bank_rd_release_port[0]=outstanding_reader;#0.1;
    if(!bank_rd_release_accepted[0])$fatal(1,"engine completion release acceptance");
    tick();idle();completion_release_latched=0;outstanding_reader=0;
    if(bank_rd_busy[0])$fatal(1,"engine completion release lost");cases++;
    // Reset cancels an outstanding response, without resetting memory contents.
    s2mm_bank_enb[1]=1;s2mm_bank_addrb[1]=0;tick();idle();aresetn=0;repeat(3)tick();aresetn=1;repeat(5)tick();
    if(bank_rd_busy||bank_wr_busy||bank_subsystem_error)$fatal(1,"pending reset");cases++;
    // Free bank requests must not touch memory; error stickiness does not stall legal work.
    mm2s_bank_ena[0]=1;mm2s_bank_addra[0]=0;mm2s_bank_dina[0]='1;mm2s_bank_wea[0]='1;s2mm_bank_enb[0]=1;
    #0.1;if(mm2s_bank_ready[0]||s2mm_bank_read_ready[0])$fatal(1,"free access accepted");tick();idle();if(!router_error)$fatal(1,"free access error");
    acquire_all();if(bank_committed_prefix)$fatal(1,"acquire prefix reset");read_word(0,0);cases++;
    $display("NATIVE_BANK_CASES=%0d responses=%0d accepted_reads=%0d",cases,responses,accepted_reads);
    $display("NATIVE_BANK_XSIM_PASS");$finish;
  end
  initial begin #20000;$fatal(1,"timeout");end
endmodule
