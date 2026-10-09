`timescale 1ns/1ps
module tb_sparse_isa_dispatcher_independent;
  import bank_config_pkg::*;
  logic aclk=0,aresetn=0; always #2.5 aclk=~aclk;
  logic start,busy,done,error; logic[7:0] error_code; logic[3:0] pc;
  logic cmd_enb; logic[3:0] cmd_addrb; logic[127:0] cmd_doutb,mem[0:15];
  logic mmv,mmr; logic[31:0] mma,mmoff; logic[22:0] mmbtt; logic[3:0] mmbank,mmtag;
  logic mmstv,mmstr,mmste; logic[3:0] mmsttag; logic[7:0] mmstec;
  logic s2v,s2r; logic[31:0] s2a,s2off; logic[22:0] s2btt; logic[3:0] s2bank,s2tag;
  logic s2stv,s2str,s2ste; logic[3:0] s2sttag; logic[7:0] s2stec;
  logic sav,sar; logic[5:0] sam; logic[10:0] san; logic[11:0] sak;
  logic[3:0] saab,sawb,saob; logic[31:0] saoba;
  logic sadv,sadr,sade; logic[3:0] sadab,sadwb,sadob;
  logic[0:15] acqv,relv,bank_busy; logic[0:15][2:0] acqp,relp,bank_owner;
  integer i,own_i,cases=0;

  sparse_isa_dispatcher #(.CMD_ADDR_WIDTH(4),.MAX_COMMANDS(16)) dut(
    .aclk,.aresetn,.cmd_dispatcher_start(start),.cmd_dispatcher_busy(busy),
    .cmd_dispatcher_done(done),.cmd_dispatcher_error(error),
    .cmd_dispatcher_error_code(error_code),.current_pc(pc),.cmd_enb,.cmd_addrb,.cmd_doutb,
    .m_ctrl_mm2s_cmd_valid(mmv),.m_ctrl_mm2s_cmd_ready(mmr),.m_ctrl_mm2s_cmd_addr(mma),
    .m_ctrl_mm2s_cmd_btt(mmbtt),.m_ctrl_mm2s_cmd_offset(mmoff),.m_ctrl_mm2s_cmd_bank(mmbank),
    .m_ctrl_mm2s_cmd_tag(mmtag),.s_ctrl_mm2s_sts_valid(mmstv),.m_ctrl_mm2s_sts_ready(mmstr),
    .s_ctrl_mm2s_sts_tag(mmsttag),.s_ctrl_mm2s_sts_error(mmste),.s_ctrl_mm2s_sts_error_code(mmstec),
    .m_ctrl_s2mm_cmd_valid(s2v),.m_ctrl_s2mm_cmd_ready(s2r),.m_ctrl_s2mm_cmd_addr(s2a),
    .m_ctrl_s2mm_cmd_btt(s2btt),.m_ctrl_s2mm_cmd_offset(s2off),.m_ctrl_s2mm_cmd_bank(s2bank),
    .m_ctrl_s2mm_cmd_tag(s2tag),.s_ctrl_s2mm_sts_valid(s2stv),.m_ctrl_s2mm_sts_ready(s2str),
    .s_ctrl_s2mm_sts_tag(s2sttag),.s_ctrl_s2mm_sts_error(s2ste),.s_ctrl_s2mm_sts_error_code(s2stec),
    .m_ctrl_sa_cmd_valid(sav),.m_ctrl_sa_cmd_ready(sar),.m_ctrl_sa_m_size(sam),
    .m_ctrl_sa_n_size(san),.m_ctrl_sa_k_size(sak),.m_ctrl_sa_act_bank(saab),
    .m_ctrl_sa_wgt_bank(sawb),.m_ctrl_sa_out_bank(saob),.m_ctrl_sa_out_base_addr(saoba),
    .s_ctrl_sa_done_valid(sadv),.m_ctrl_sa_done_ready(sadr),.s_ctrl_sa_done_error(sade),
    .s_ctrl_sa_act_bank(sadab),.s_ctrl_sa_wgt_bank(sadwb),.s_ctrl_sa_out_bank(sadob),
    .bank_acquire_valid(acqv),.bank_acquire_port(acqp),.bank_release_valid(relv),
    .bank_release_port(relp),.bank_busy,.bank_owner_port(bank_owner));

  function automatic logic[127:0] mkcmd(input logic[3:0] op,b0,b1,b2,
    input logic[31:0] off,input logic[22:0] btt,input logic[31:0] addr);
    mkcmd={op,b0,b1,b2,off,btt,addr,25'd0};
  endfunction
  function automatic logic[31:0] shape(input logic[5:0] m,input logic[10:0] n,input logic[11:0] k);
    shape={m,n,k,3'b000};
  endfunction

  always_ff @(posedge aclk) begin
    if(!aresetn) cmd_doutb<='0; else if(cmd_enb) cmd_doutb<=mem[cmd_addrb];
  end
  always_ff @(posedge aclk) begin
    if(!aresetn) begin bank_busy<='0; bank_owner<='0; end
    else for(own_i=0;own_i<16;own_i=own_i+1) begin
      if(relv[own_i]) begin
        if(!bank_busy[own_i]||bank_owner[own_i]!=relp[own_i]) $fatal(1,"bad release");
        bank_busy[own_i]<=0; bank_owner[own_i]<=0;
      end
      if(acqv[own_i]) begin
        if(bank_busy[own_i]) $fatal(1,"double acquire");
        bank_busy[own_i]<=1; bank_owner[own_i]<=acqp[own_i];
      end
    end
  end

  task automatic idle; begin
    start=0; mmr=1; s2r=1; sar=1;
    mmstv=0; mmsttag=0; mmste=0; mmstec=0;
    s2stv=0; s2sttag=0; s2ste=0; s2stec=0;
    sadv=0; sade=0; sadab=0; sadwb=0; sadob=0;
  end endtask
  task automatic reset_dut; begin
    aresetn=0; idle(); repeat(4) @(posedge aclk); #1; aresetn=1; repeat(2) @(posedge aclk); #1;
  end endtask
  task automatic launch; begin
    @(negedge aclk); start=1; @(posedge aclk); #1; @(negedge aclk); start=0;
  end endtask
  task automatic wait_mmv; integer t; begin
    t=0; while(!mmv&&t<50) begin @(posedge aclk); #1; t=t+1; end
    if(!mmv) $fatal(1,"MM2S timeout");
  end endtask
  task automatic wait_s2v; integer t; begin
    t=0; while(!s2v&&t<50) begin @(posedge aclk); #1; t=t+1; end
    if(!s2v) $fatal(1,"S2MM timeout");
  end endtask
  task automatic wait_error(input logic[7:0] expected); integer t; begin
    t=0; while(!error&&t<80) begin @(posedge aclk); #1; t=t+1; end
    if(!error||error_code!=expected) $fatal(1,"error got=%0h expected=%0h",error_code,expected);
  end endtask
  task automatic mmrsp(input logic[3:0] tag,input logic err,input logic[7:0] code); begin
    @(negedge aclk); mmsttag=tag; mmste=err; mmstec=code; mmstv=1;
    while(!mmstr) begin @(posedge aclk); #1; end
    @(posedge aclk); #1; @(negedge aclk); mmstv=0; mmste=0; mmstec=0;
  end endtask
  task automatic s2rsp(input logic[3:0] tag,input logic err,input logic[7:0] code); begin
    @(negedge aclk); s2sttag=tag; s2ste=err; s2stec=code; s2stv=1;
    while(!s2str) begin @(posedge aclk); #1; end
    @(posedge aclk); #1; @(negedge aclk); s2stv=0; s2ste=0; s2stec=0;
  end endtask

  initial begin
    for(i=0;i<16;i=i+1) mem[i]=mkcmd(0,0,0,0,0,0,0);
    idle(); reset_dut();

    // Local-offset upper bits and raw GEMM address reject before issue/acquire.
    mem[0]=mkcmd(1,0,0,0,32'h0080_0000,23'd8,0); launch(); wait_error(8'h02);
    if(mmv||acqv!='0||bank_busy!='0) $fatal(1,"upper offset escaped legality gate");
    reset_dut(); mem[0]=mkcmd(3,1,2,3,shape(1,1,1),0,32'h4); launch(); wait_error(8'h02);
    if(sav||saoba!=0||acqv!='0||bank_busy!='0) $fatal(1,"GEMM raw address escaped gate");
    cases++; $display("INDEP legality/GEMM-zero PASS"); reset_dut();

    // A held response cannot fire while a second offered request is stalled.
    mem[0]=mkcmd(1,0,0,0,0,23'd8,32'h1000);
    mem[1]=mkcmd(1,1,0,0,8,23'd8,32'h2000); mem[2]=mkcmd(0,0,0,0,0,0,0);
    launch(); wait_mmv(); @(posedge aclk); #1; mmr=0; wait_mmv();
    if(mmbank!=1||mma!=32'h2000) $fatal(1,"second request payload");
    @(negedge aclk); mmsttag=0; mmste=0; mmstec=0; mmstv=1; #1;
    repeat(4) begin @(posedge aclk); #1;
      if(mmstr||relv!='0||!mmv||mmbank!=1||mma!=32'h2000||mmsttag!=0||mmstec!=0)
        $fatal(1,"valid-ready/request stability violation");
    end
    @(negedge aclk); mmr=1; @(posedge aclk); #1;
    if(!mmstr) $fatal(1,"response did not become ready after request fire");
    @(posedge aclk); #1; @(negedge aclk); mmstv=0;
    if(bank_busy[0]||!bank_busy[1]) $fatal(1,"wrong release on response handshake");
    mmrsp(1,0,0); while(!done) begin @(posedge aclk); #1; end
    cases++; $display("INDEP valid-ready/stability/END-drain PASS"); reset_dut();

    // Unknown nonzero is fail-closed: report exact code, retain pending and owner.
    mem[0]=mkcmd(1,0,0,0,0,23'd8,0); mem[1]=mkcmd(0,0,0,0,0,0,0);
    launch(); wait_mmv(); @(posedge aclk); #1; mmrsp(0,1,8'h7e);
    repeat(4) begin @(posedge aclk); #1;
      if(error||!busy||error_code!=8'h7e||!bank_busy[0]||!dut.pending_mm2s_r[0]||relv!='0)
        $fatal(1,"unknown MM2S did not retain");
    end
    cases++; $display("INDEP unknown-MM2S retain PASS"); reset_dut();

    // The S2MM path has the same unknown-code policy.
    mem[0]=mkcmd(2,3,0,0,0,23'd8,0); mem[1]=mkcmd(0,0,0,0,0,0,0);
    launch(); wait_s2v(); @(posedge aclk); #1; s2rsp(3,1,8'h7d);
    repeat(3) begin @(posedge aclk); #1;
      if(error||!busy||error_code!=8'h7d||!bank_busy[3]||!dut.pending_s2mm_r[3]||relv!='0)
        $fatal(1,"unknown S2MM did not retain");
    end
    cases++; $display("INDEP unknown-S2MM retain PASS"); reset_dut();

    // error=1/code=00 maps to FF and retains; reset is the recovery mechanism.
    mem[0]=mkcmd(1,0,0,0,0,23'd8,0); mem[1]=mkcmd(0,0,0,0,0,0,0);
    launch(); wait_mmv(); @(posedge aclk); #1; mmrsp(0,1,8'h00);
    repeat(3) begin @(posedge aclk); #1;
      if(error_code!=8'hff||!bank_busy[0]||!dut.pending_mm2s_r[0]||relv!='0) $fatal(1,"00 fail-closed");
    end
    reset_dut(); if(busy||error||bank_busy!='0||dut.pending_mm2s_r!='0) $fatal(1,"reset recovery");
    cases++; $display("INDEP inconsistent/reset-recovery PASS");

    // A mismatched success is ERR_RESPONSE and cannot release; the later match drains ownership.
    mem[0]=mkcmd(1,0,0,0,0,23'd8,0); mem[1]=mkcmd(0,0,0,0,0,0,0);
    launch(); wait_mmv(); @(posedge aclk); #1; mmrsp(1,0,0);
    if(!bank_busy[0]||!dut.pending_mm2s_r[0]||relv!='0) $fatal(1,"mismatch released owner");
    mmrsp(0,0,0); wait_error(8'h03);
    if(bank_busy!='0||dut.pending_mm2s_r!='0) $fatal(1,"matching drain failed");
    cases++; $display("INDEP mismatch/drain PASS"); reset_dut();

    // Repeated launch after recovery remains functional.
    mem[0]=mkcmd(1,0,0,0,0,23'd8,0); mem[1]=mkcmd(0,0,0,0,0,0,0);
    launch(); wait_mmv(); @(posedge aclk); #1; mmrsp(0,0,0);
    while(!done) begin @(posedge aclk); #1; end
    cases++; $display("INDEP repeat PASS");
    $display("SPARSE_ISA_DISPATCHER_INDEPENDENT_XSIM_PASS cases=%0d",cases); $finish;
  end
endmodule
