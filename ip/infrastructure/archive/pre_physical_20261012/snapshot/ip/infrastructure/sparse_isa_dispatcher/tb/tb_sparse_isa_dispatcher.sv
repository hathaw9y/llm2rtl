`timescale 1ns/1ps
module tb_sparse_isa_dispatcher;
  import bank_config_pkg::*;
  logic aclk=0,aresetn=0;always #2.5 aclk=~aclk;
  logic start,busy,done,error;logic[7:0]error_code;logic[3:0]pc;
  logic cmd_enb;logic[3:0]cmd_addrb;logic[127:0]cmd_doutb;logic[127:0]mem[0:15];
  logic mmv,mmr;logic[31:0]mma;logic[22:0]mmbtt;logic[31:0]mmoff;logic[3:0]mmbank,mmtag;
  logic mmstv,mmstr;logic[3:0]mmsttag;logic mmste;logic[7:0]mmstec;
  logic s2v,s2r;logic[31:0]s2a;logic[22:0]s2btt;logic[31:0]s2off;logic[3:0]s2bank,s2tag;
  logic s2stv,s2str;logic[3:0]s2sttag;logic s2ste;logic[7:0]s2stec;
  logic sav,sar;logic[5:0]sam;logic[10:0]san;logic[11:0]sak;
  logic[3:0]saab,sawb,saob;logic[31:0]saoba;
  logic sadv,sadr,sade;logic[3:0]sadab,sadwb,sadob;
  logic[0:15]acqv,relv,bank_busy;logic[0:15][2:0]acqp,relp,bank_owner;
  integer cases=0,i;integer own_i;

  sparse_isa_dispatcher #(.CMD_ADDR_WIDTH(4),.MAX_COMMANDS(16)) dut(
    .aclk,.aresetn,.cmd_dispatcher_start(start),.cmd_dispatcher_busy(busy),
    .cmd_dispatcher_done(done),.cmd_dispatcher_error(error),
    .cmd_dispatcher_error_code(error_code),.current_pc(pc),.cmd_enb,.cmd_addrb,.cmd_doutb,
    .m_ctrl_mm2s_cmd_valid(mmv),.m_ctrl_mm2s_cmd_ready(mmr),.m_ctrl_mm2s_cmd_addr(mma),
    .m_ctrl_mm2s_cmd_btt(mmbtt),.m_ctrl_mm2s_cmd_offset(mmoff),.m_ctrl_mm2s_cmd_bank(mmbank),
    .m_ctrl_mm2s_cmd_tag(mmtag),.s_ctrl_mm2s_sts_valid(mmstv),.m_ctrl_mm2s_sts_ready(mmstr),
    .s_ctrl_mm2s_sts_tag(mmsttag),.s_ctrl_mm2s_sts_error(mmste),
    .s_ctrl_mm2s_sts_error_code(mmstec),
    .m_ctrl_s2mm_cmd_valid(s2v),.m_ctrl_s2mm_cmd_ready(s2r),.m_ctrl_s2mm_cmd_addr(s2a),
    .m_ctrl_s2mm_cmd_btt(s2btt),.m_ctrl_s2mm_cmd_offset(s2off),.m_ctrl_s2mm_cmd_bank(s2bank),
    .m_ctrl_s2mm_cmd_tag(s2tag),.s_ctrl_s2mm_sts_valid(s2stv),.m_ctrl_s2mm_sts_ready(s2str),
    .s_ctrl_s2mm_sts_tag(s2sttag),.s_ctrl_s2mm_sts_error(s2ste),
    .s_ctrl_s2mm_sts_error_code(s2stec),
    .m_ctrl_sa_cmd_valid(sav),.m_ctrl_sa_cmd_ready(sar),.m_ctrl_sa_m_size(sam),
    .m_ctrl_sa_n_size(san),.m_ctrl_sa_k_size(sak),.m_ctrl_sa_act_bank(saab),
    .m_ctrl_sa_wgt_bank(sawb),.m_ctrl_sa_out_bank(saob),.m_ctrl_sa_out_base_addr(saoba),
    .s_ctrl_sa_done_valid(sadv),.m_ctrl_sa_done_ready(sadr),.s_ctrl_sa_done_error(sade),
    .s_ctrl_sa_act_bank(sadab),.s_ctrl_sa_wgt_bank(sadwb),.s_ctrl_sa_out_bank(sadob),
    .bank_acquire_valid(acqv),.bank_acquire_port(acqp),.bank_release_valid(relv),
    .bank_release_port(relp),.bank_busy,.bank_owner_port(bank_owner));

  function automatic logic[127:0]mkcmd(input logic[3:0]op,input logic[3:0]b0,b1,b2,
    input logic[31:0]off,input logic[22:0]btt,input logic[31:0]addr);
    mkcmd={op,b0,b1,b2,off,btt,addr,25'd0};
  endfunction
  function automatic logic[31:0]shape(input logic[5:0]m,input logic[10:0]n,input logic[11:0]k);
    shape={m,n,k,3'b000};
  endfunction
  function automatic logic[7:0]transport_code(input integer index);
    case(index)
      0:transport_code=8'h10;1:transport_code=8'h20;2:transport_code=8'h30;
      3:transport_code=8'h40;default:transport_code=8'h50;
    endcase
  endfunction

  always_ff @(posedge aclk)begin if(!aresetn)cmd_doutb<='0;else if(cmd_enb)cmd_doutb<=mem[cmd_addrb];end
  always_ff @(posedge aclk)begin
    if(!aresetn)begin bank_busy<='0;bank_owner<='0;end else begin
      for(own_i=0;own_i<16;own_i=own_i+1)begin
        if(relv[own_i])begin
          if(!bank_busy[own_i]||bank_owner[own_i]!=relp[own_i])$fatal(1,"illegal release b=%0d",own_i);
          bank_busy[own_i]<=0;bank_owner[own_i]<=0;
        end
        if(acqv[own_i])begin
          if(bank_busy[own_i])$fatal(1,"acquire busy b=%0d",own_i);
          bank_busy[own_i]<=1;bank_owner[own_i]<=acqp[own_i];
        end
      end
    end
  end

  task automatic idle_inputs;begin
    start=0;mmr=1;s2r=1;sar=1;mmstv=0;mmsttag=0;mmste=0;mmstec=0;
    s2stv=0;s2sttag=0;s2ste=0;s2stec=0;
    sadv=0;sade=0;sadab=0;sadwb=0;sadob=0;end endtask
  task automatic reset_dut;begin
    aresetn=0;idle_inputs();repeat(4)@(posedge aclk);#1;aresetn=1;repeat(2)@(posedge aclk);#1;
  end endtask
  task automatic launch;begin @(negedge aclk);start=1;@(posedge aclk);#1;@(negedge aclk);start=0;end endtask
  task automatic wait_mmv;integer t;begin t=0;while(!mmv&&t<40)begin @(posedge aclk);#1;t=t+1;end
    if(!mmv)$fatal(1,"timeout MM2S");end endtask
  task automatic wait_s2v;integer t;begin t=0;while(!s2v&&t<40)begin @(posedge aclk);#1;t=t+1;end
    if(!s2v)$fatal(1,"timeout S2MM");end endtask
  task automatic wait_sav;integer t;begin t=0;while(!sav&&t<40)begin @(posedge aclk);#1;t=t+1;end
    if(!sav)$fatal(1,"timeout SA");end endtask
  task automatic wait_done;integer t;begin t=0;while(!done&&t<80)begin @(posedge aclk);#1;t=t+1;end
    if(!done)$fatal(1,"timeout done err=%0d pc=%0d",error_code,pc);end endtask
  task automatic wait_error(input logic[7:0]exp);integer t;begin t=0;while(!error&&t<80)begin @(posedge aclk);#1;t=t+1;end
    if(!error||error_code!=exp)$fatal(1,"error mismatch got=%0d exp=%0d",error_code,exp);end endtask
  task automatic mmcomplete(input logic[3:0]tag,input logic[7:0]code);begin
    @(negedge aclk);mmsttag=tag;mmstec=code;mmste=(code!=0);mmstv=1;#1;
    while(!mmstr)begin @(posedge aclk);#1;end
    @(posedge aclk);#1;@(negedge aclk);mmstv=0;mmste=0;mmstec=0;end endtask
  task automatic s2complete(input logic[3:0]tag,input logic[7:0]code);begin
    @(negedge aclk);s2sttag=tag;s2stec=code;s2ste=(code!=0);s2stv=1;#1;
    while(!s2str)begin @(posedge aclk);#1;end
    @(posedge aclk);#1;@(negedge aclk);s2stv=0;s2ste=0;s2stec=0;end endtask
  task automatic sacomplete(input logic[3:0]a,w,o,input logic err);begin
    @(negedge aclk);sadab=a;sadwb=w;sadob=o;sade=err;sadv=1;#1;if(!sadr)$fatal(1,"SA done not ready");
    @(posedge aclk);#1;@(negedge aclk);sadv=0;sade=0;end endtask

  initial begin
    for(i=0;i<16;i=i+1)mem[i]=mkcmd(0,0,0,0,0,0,0);
    idle_inputs();reset_dut();
    if(busy||done||error||acqv!='0||relv!='0)$fatal(1,"reset outputs");
    cases++;$display("CASE reset PASS");

    // Typed MM2S payload, bank zero, END drain.
    mem[0]=mkcmd(1,0,0,0,32'h1234,23'd64,32'h80001000);mem[1]=mkcmd(0,0,0,0,0,0,0);
    mmr=0;launch();wait_mmv();
    if(mma!=32'h80001000||mmbtt!=64||mmoff!=32'h1234||mmbank!=0||mmtag!=0)$fatal(1,"MM2S payload");
    repeat(3)begin @(posedge aclk);#1;if(!mmv||mma!=32'h80001000||acqv!='0)$fatal(1,"MM2S backpressure stability");end
    @(negedge aclk);mmr=1;#1;if(!acqv[0]||acqp[0]!=OWNER_MM2S)$fatal(1,"MM2S acquire");@(posedge aclk);#1;
    repeat(8)@(posedge aclk);#1;if(done)$fatal(1,"END did not drain");mmcomplete(0,0);wait_done();
    cases++;$display("CASE MM2S bank0 payload/backpressure/drain PASS");reset_dut();

    // S2MM exact payload and owner2.
    mem[0]=mkcmd(2,3,0,0,32'h88,23'd128,32'h90002000);mem[1]=mkcmd(0,0,0,0,0,0,0);
    launch();wait_s2v();if(s2a!=32'h90002000||s2btt!=128||s2off!=32'h88||s2bank!=3||s2tag!=3)$fatal(1,"S2MM payload");
    if(!acqv[3]||acqp[3]!=OWNER_S2MM)$fatal(1,"S2MM acquire");@(posedge aclk);#1;s2complete(3,0);wait_done();
    cases++;$display("CASE S2MM payload PASS");reset_dut();

    // Two nonconflicting DMA commands issue before either completion.
    mem[0]=mkcmd(1,0,0,0,0,23'd16,32'h1000);mem[1]=mkcmd(1,1,0,0,4,23'd16,32'h2000);
    mem[2]=mkcmd(2,3,0,0,8,23'd32,32'h3000);mem[3]=mkcmd(0,0,0,0,0,0,0);
    launch();wait_mmv();@(posedge aclk);#1;wait_mmv();if(mmbank!=1)$fatal(1,"second DMA bank");
    @(posedge aclk);#1;wait_s2v();if(s2bank!=3)$fatal(1,"concurrent S2MM");@(posedge aclk);#1;
    if(!(bank_busy[0]&&bank_busy[1]&&bank_busy[3]))$fatal(1,"DMA concurrency ownership");
    mmcomplete(1,0);s2complete(3,0);mmcomplete(0,0);wait_done();
    cases++;$display("CASE concurrent DMA PASS");reset_dut();

    // Same bank strict-PC stall, then release allows issue.
    mem[0]=mkcmd(1,0,0,0,0,23'd8,32'h1110);mem[1]=mkcmd(1,0,0,0,4,23'd8,32'h2220);mem[2]=mkcmd(0,0,0,0,0,0,0);
    launch();wait_mmv();@(posedge aclk);#1;repeat(12)begin @(posedge aclk);#1;if(pc!=1||mmv)$fatal(1,"same-bank no-lookahead");end
    mmcomplete(0,0);wait_mmv();if(mma!=32'h2220)$fatal(1,"second same bank payload");@(posedge aclk);#1;mmcomplete(0,0);wait_done();
    cases++;$display("CASE same-bank stall/release PASS");reset_dut();

    // GEMM exact fixed banks, shape, output base and atomic owner3/4/5.
    mem[0]=mkcmd(3,1,2,3,shape(6'd32,11'd1536,12'd1024),0,32'h00000000);mem[1]=mkcmd(0,0,0,0,0,0,0);
    sar=0;launch();wait_sav();
    if(sam!=32||san!=1536||sak!=1024||saab!=1||sawb!=2||saob!=3||saoba!=32'h0)$fatal(1,"SA bank-only payload");
    repeat(3)begin @(posedge aclk);#1;if(!sav||sam!=32||san!=1536||sak!=1024||acqv!='0)$fatal(1,"SA backpressure");end
    @(negedge aclk);sar=1;#1;
    if(!(acqv[1]&&acqv[2]&&acqv[3])||acqp[1]!=OWNER_SA_ACT||acqp[2]!=OWNER_SA_WGT||acqp[3]!=OWNER_SA_OUT)$fatal(1,"SA atomic acquire");
    @(posedge aclk);#1;sacomplete(1,2,3,0);wait_done();
    cases++;$display("CASE GEMM payload/backpressure/atomic roles PASS");reset_dut();

    // Capability failures happen before any executor valid/acquire.
    mem[0]=mkcmd(1,3,0,0,0,23'd4,0);launch();
    while(!error)begin @(posedge aclk);#1;if(mmv||s2v||sav||acqv!='0)$fatal(1,"MM2S capability leaked");end
    if(error_code!=2)$fatal(1,"MM2S capability code");cases++;reset_dut();
    mem[0]=mkcmd(2,2,0,0,0,23'd4,0);launch();
    while(!error)begin @(posedge aclk);#1;if(mmv||s2v||sav||acqv!='0)$fatal(1,"S2MM capability leaked");end
    if(error_code!=2)$fatal(1,"S2MM capability code");cases++;reset_dut();
    mem[0]=mkcmd(3,0,2,3,shape(1,1,1),0,0);launch();
    while(!error)begin @(posedge aclk);#1;if(mmv||s2v||sav||acqv!='0)$fatal(1,"GEMM capability leaked");end
    if(error_code!=2)$fatal(1,"GEMM capability code");cases++;
    $display("CASE capability rejects x3 PASS");reset_dut();

    // DMA local offsets must fit the 23-bit engine boundary without truncation.
    mem[0]=mkcmd(1,0,0,0,32'h0080_0000,23'd4,0);launch();wait_error(2);
    if(mmv||acqv!='0)$fatal(1,"MM2S upper offset leaked");reset_dut();
    mem[0]=mkcmd(2,3,0,0,32'h8000_0000,23'd4,0);launch();wait_error(2);
    if(s2v||acqv!='0)$fatal(1,"S2MM upper offset leaked");
    cases++;$display("CASE DMA upper-offset truncation rejects PASS");reset_dut();

    // Compute is bank-only: raw/output address metadata must be zero.
    mem[0]=mkcmd(3,1,2,3,shape(1,1,1),0,32'h4);launch();wait_error(2);
    if(sav||acqv!='0||saoba!=0)$fatal(1,"GEMM nonzero address leaked");
    cases++;$display("CASE GEMM nonzero address reject PASS");reset_dut();

    // Zero GEMM shape is an operand error.
    mem[0]=mkcmd(3,1,2,3,shape(0,1,1),0,0);launch();wait_error(2);
    if(sav||acqv!='0)$fatal(1,"zero shape leaked");cases++;$display("CASE zero shape reject PASS");reset_dut();

    // Spurious DMA completion cannot release; matching completion drains error.
    mem[0]=mkcmd(1,0,0,0,0,23'd8,0);mem[1]=mkcmd(0,0,0,0,0,0,0);launch();wait_mmv();@(posedge aclk);#1;
    @(negedge aclk);mmsttag=1;mmstv=1;#1;if(relv!='0)$fatal(1,"spurious release");@(posedge aclk);#1;@(negedge aclk);mmstv=0;
    if(!bank_busy[0])$fatal(1,"spurious cleared bank");mmcomplete(0,0);wait_error(3);
    cases++;$display("CASE spurious completion error-drain PASS");reset_dut();

    // A wrong GEMM tuple is spurious and must not release any of the three banks.
    mem[0]=mkcmd(3,1,2,3,shape(2,3,4),0,32'h0);mem[1]=mkcmd(0,0,0,0,0,0,0);launch();wait_sav();@(posedge aclk);#1;
    @(negedge aclk);sadab=1;sadwb=2;sadob=0;sadv=1;#1;if(relv!='0)$fatal(1,"wrong SA tuple released bank");
    @(posedge aclk);#1;@(negedge aclk);sadv=0;
    if(!(bank_busy[1]&&bank_busy[2]&&bank_busy[3]))$fatal(1,"wrong SA tuple cleared ownership");
    sacomplete(1,2,3,0);wait_error(3);
    cases++;$display("CASE wrong GEMM tuple no release PASS");reset_dut();

    // Executor failure releases exact GEMM tuple, then enters executor error.
    mem[0]=mkcmd(3,1,2,3,shape(2,4,8),0,32'h0);mem[1]=mkcmd(0,0,0,0,0,0,0);launch();wait_sav();@(posedge aclk);#1;
    sacomplete(1,2,3,1);wait_error(4);if(bank_busy!='0)$fatal(1,"executor failure did not release");
    cases++;$display("CASE GEMM executor-error release PASS");reset_dut();

    // A response is backpressured while the next request is stalled; neither
    // request nor response payload may change before its handshake.
    mem[0]=mkcmd(1,0,0,0,0,23'd8,32'h1000);mem[1]=mkcmd(1,1,0,0,8,23'd8,32'h2000);
    mem[2]=mkcmd(0,0,0,0,0,0,0);mmr=1;launch();wait_mmv();@(posedge aclk);#1;
    mmr=0;wait_mmv();if(mmbank!=1||mma!=32'h2000)$fatal(1,"second request missing");
    @(negedge aclk);mmsttag=0;mmste=0;mmstec=0;mmstv=1;#1;
    if(mmstr||relv!='0)$fatal(1,"response not backpressured during issue");
    repeat(3)begin @(posedge aclk);#1;
      if(!mmv||mmbank!=1||mma!=32'h2000||mmstr||relv!='0||mmsttag!=0||mmstec!=0)
        $fatal(1,"request/response backpressure stability");
    end
    @(negedge aclk);mmr=1;@(posedge aclk);#1;
    if(!mmstr)$fatal(1,"response ready sequencing");
    @(posedge aclk);#1;if(bank_busy[0]||!bank_busy[1])$fatal(1,"response handshake release identity");
    @(negedge aclk);mmstv=0;mmcomplete(1,0);wait_done();
    cases++;$display("CASE response valid-ready backpressure/stability PASS");reset_dut();

    // Every descriptor code retires the matching pending command and releases
    // ownership before reporting the exact code.
    for(i=1;i<=6;i=i+1)begin
      mem[0]=mkcmd(1,0,0,0,0,23'd8,32'h1000);mem[1]=mkcmd(0,0,0,0,0,0,0);
      launch();wait_mmv();@(posedge aclk);#1;mmcomplete(0,i[7:0]);wait_error(i[7:0]);
      if(bank_busy!='0||dut.pending_mm2s_r!='0)$fatal(1,"descriptor code did not retire code=%0h",i);
      reset_dut();
    end
    // Also exercise the S2MM code input on a retiring descriptor error.
    mem[0]=mkcmd(2,3,0,0,0,23'd8,32'h1000);mem[1]=mkcmd(0,0,0,0,0,0,0);
    launch();wait_s2v();@(posedge aclk);#1;s2complete(3,8'h06);wait_error(8'h06);
    if(bank_busy!='0||dut.pending_s2mm_r!='0)$fatal(1,"S2MM descriptor code did not retire");
    cases++;$display("CASE DMA descriptor codes 01..06 retire/release PASS");reset_dut();

    // Transport/recovery faults are diagnostics, not retirements. They retain
    // pending state and ownership, never pulse release, and require reset.
    for(i=0;i<5;i=i+1)begin
      mem[0]=mkcmd(1,0,0,0,0,23'd8,32'h1000);mem[1]=mkcmd(0,0,0,0,0,0,0);
      launch();wait_mmv();@(posedge aclk);#1;
      @(negedge aclk);mmsttag=0;mmstec=transport_code(i);mmste=1;mmstv=1;#1;
      if(!mmstr||relv!='0)$fatal(1,"transport pre-handshake release code=%0h",transport_code(i));
      @(posedge aclk);#1;@(negedge aclk);mmstv=0;mmste=0;mmstec=0;
      repeat(4)begin @(posedge aclk);#1;
        if(relv!='0||!bank_busy[0]||!dut.pending_mm2s_r[0]||!busy||error||
           error_code!=transport_code(i))$fatal(1,"transport retention code=%0h",transport_code(i));
      end
      reset_dut();
    end
    // S2MM transport path gets the same fail-retain policy.
    mem[0]=mkcmd(2,3,0,0,0,23'd8,32'h1000);mem[1]=mkcmd(0,0,0,0,0,0,0);
    launch();wait_s2v();@(posedge aclk);#1;
    @(negedge aclk);s2sttag=3;s2stec=8'h10;s2ste=1;s2stv=1;#1;
    if(!s2str||relv!='0)$fatal(1,"S2MM transport pre-handshake release");
    @(posedge aclk);#1;@(negedge aclk);s2stv=0;s2ste=0;s2stec=0;
    repeat(3)begin @(posedge aclk);#1;
      if(relv!='0||!bank_busy[3]||!dut.pending_s2mm_r[3]||!busy||error||error_code!=8'h10)
        $fatal(1,"S2MM transport retention");
    end
    cases++;$display("CASE DMA transport codes 10/20/30/40/50 retain/no-release/reset PASS");reset_dut();

    // Reset while request is stalled flushes valid and all state; repeated start works.
    mem[0]=mkcmd(3,1,2,3,shape(3,5,7),0,0);mem[1]=mkcmd(0,0,0,0,0,0,0);sar=0;launch();wait_sav();
    @(negedge aclk);aresetn=0;repeat(3)@(posedge aclk);#1;if(sav||busy||done||error||acqv!='0||relv!='0)$fatal(1,"active reset flush");
    aresetn=1;sar=1;repeat(2)@(posedge aclk);#1;launch();wait_sav();@(posedge aclk);#1;sacomplete(1,2,3,0);wait_done();
    @(negedge aclk);start=0;repeat(2)@(posedge aclk);#1;launch();wait_sav();@(posedge aclk);#1;sacomplete(1,2,3,0);wait_done();
    cases++;$display("CASE reset/repeated program PASS");

    $display("SPARSE_ISA_DISPATCHER_XSIM_PASS cases=%0d",cases);$finish;
  end
endmodule
