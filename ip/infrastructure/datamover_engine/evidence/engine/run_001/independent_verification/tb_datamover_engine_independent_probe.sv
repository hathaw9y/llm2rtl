`timescale 1ns/1ps
import datamover_engine_pkg::*;
module tb_datamover_engine_independent_probe;
  localparam int BANK_NUM=3, BANK_WIDTH=2;
  logic aclk=0,aresetn=0; always #2.5 aclk=~aclk;
  logic rpause,rabort,rcpl_ready,rfault,rvalid,rready,rsts_valid,rsts_err;
  logic [3:0] rtag,rrecv; logic [7:0] rraw,rsts_code; logic [31:0] raddr; logic [22:0] rbtt,roff; logic [1:0] rbank,rsts_bank;
  logic wpause,wabort,wcpl_ready,wfault,wvalid,wready,wsts_valid,wsts_err;
  logic [3:0] wtag,wrecv; logic [7:0] wraw,wsts_code; logic [31:0] waddr; logic [22:0] wbtt,woff; logic [1:0] wbank,wsts_bank;
  logic [71:0] rcmd,wcmd; logic rcmd_valid,rcmd_ready,wcmd_valid,wcmd_ready;
  logic [63:0] rdata; logic [7:0] rkeep; logic rdata_valid,rdata_ready,rlast;
  logic [7:0] rstatus; logic rstatus_keep,rstatus_valid,rstatus_ready,rstatus_last;
  logic [63:0] wdata; logic [7:0] wkeep; logic wdata_valid,wdata_ready,wlast;
  logic [7:0] wstatus; logic wstatus_keep,wstatus_valid,wstatus_ready,wstatus_last;
  logic wr_req[BANK_NUM],wr_grant[BANK_NUM],rstart[BANK_NUM],rdone[BANK_NUM],rabort_bank[BANK_NUM];
  logic [22:0] roffset[BANK_NUM]; logic [63:0] rbank_data[BANK_NUM]; logic [7:0] rbank_keep[BANK_NUM];
  logic rbank_valid[BANK_NUM],rbank_ready[BANK_NUM],rbank_last[BANK_NUM];
  logic rd_req[BANK_NUM],rd_grant[BANK_NUM],wstart[BANK_NUM],wdone[BANK_NUM],wabort_bank[BANK_NUM];
  logic [22:0] wbtt_bank[BANK_NUM],woffset[BANK_NUM]; logic [63:0] wbank_data[BANK_NUM]; logic [7:0] wbank_keep[BANK_NUM];
  logic wbank_valid[BANK_NUM],wbank_ready[BANK_NUM],wbank_last[BANK_NUM];
  integer i;

  datamover_engine #(.BANK_NUM(BANK_NUM),.BANK_WIDTH(BANK_WIDTH),
    .BANK_WORD_BYTES({32'd16,32'd8,32'd4}),
    .BANK_CAPACITY_BYTES({32'd4096,32'd2048,32'd1024})) dut(
    .aclk,.aresetn,
    .s_ctrl_mm2s_pause(rpause),.s_ctrl_mm2s_abort(rabort),.m_ctrl_mm2s_sts_ready(rcpl_ready),
    .m_ctrl_mm2s_faulted(rfault),.m_ctrl_mm2s_sts_tag(rtag),.m_ctrl_mm2s_sts_received_tag(rrecv),.m_ctrl_mm2s_sts_raw_status(rraw),
    .s_ctrl_mm2s_cmd_valid(rvalid),.s_ctrl_mm2s_cmd_ready(rready),.s_ctrl_mm2s_cmd_addr(raddr),.s_ctrl_mm2s_cmd_btt(rbtt),
    .s_ctrl_mm2s_cmd_offset(roff),.s_ctrl_mm2s_cmd_bank(rbank),.m_ctrl_mm2s_sts_valid(rsts_valid),
    .m_ctrl_mm2s_sts_error(rsts_err),.m_ctrl_mm2s_sts_error_code(rsts_code),.m_ctrl_mm2s_sts_bank(rsts_bank),
    .s_ctrl_s2mm_pause(wpause),.s_ctrl_s2mm_abort(wabort),.m_ctrl_s2mm_sts_ready(wcpl_ready),
    .m_ctrl_s2mm_faulted(wfault),.m_ctrl_s2mm_sts_tag(wtag),.m_ctrl_s2mm_sts_received_tag(wrecv),.m_ctrl_s2mm_sts_raw_status(wraw),
    .s_ctrl_s2mm_cmd_valid(wvalid),.s_ctrl_s2mm_cmd_ready(wready),.s_ctrl_s2mm_cmd_addr(waddr),.s_ctrl_s2mm_cmd_btt(wbtt),
    .s_ctrl_s2mm_cmd_offset(woff),.s_ctrl_s2mm_cmd_bank(wbank),.m_ctrl_s2mm_sts_valid(wsts_valid),
    .m_ctrl_s2mm_sts_error(wsts_err),.m_ctrl_s2mm_sts_error_code(wsts_code),.m_ctrl_s2mm_sts_bank(wsts_bank),
    .m_axis_mm2s_cmd_tdata(rcmd),.m_axis_mm2s_cmd_tvalid(rcmd_valid),.m_axis_mm2s_cmd_tready(rcmd_ready),
    .s_axis_mm2s_tdata(rdata),.s_axis_mm2s_tkeep(rkeep),.s_axis_mm2s_tvalid(rdata_valid),.s_axis_mm2s_tready(rdata_ready),.s_axis_mm2s_tlast(rlast),
    .s_axis_mm2s_sts_tdata(rstatus),.s_axis_mm2s_sts_tkeep(rstatus_keep),.s_axis_mm2s_sts_tvalid(rstatus_valid),
    .s_axis_mm2s_sts_tready(rstatus_ready),.s_axis_mm2s_sts_tlast(rstatus_last),
    .m_axis_s2mm_cmd_tdata(wcmd),.m_axis_s2mm_cmd_tvalid(wcmd_valid),.m_axis_s2mm_cmd_tready(wcmd_ready),
    .m_axis_s2mm_tdata(wdata),.m_axis_s2mm_tkeep(wkeep),.m_axis_s2mm_tvalid(wdata_valid),.m_axis_s2mm_tready(wdata_ready),.m_axis_s2mm_tlast(wlast),
    .s_axis_s2mm_sts_tdata(wstatus),.s_axis_s2mm_sts_tkeep(wstatus_keep),.s_axis_s2mm_sts_tvalid(wstatus_valid),
    .s_axis_s2mm_sts_tready(wstatus_ready),.s_axis_s2mm_sts_tlast(wstatus_last),
    .m_ctrl_bank_wr_req(wr_req),.m_ctrl_bank_wr_grant(wr_grant),.m_ctrl_mm2s_adapter_start(rstart),
    .m_ctrl_mm2s_adapter_done(rdone),.m_ctrl_mm2s_adapter_abort(rabort_bank),.m_ctrl_mm2s_adapter_offset(roffset),
    .m_axis_mm2s_tdata(rbank_data),.m_axis_mm2s_tkeep(rbank_keep),.m_axis_mm2s_tvalid(rbank_valid),
    .m_axis_mm2s_tready(rbank_ready),.m_axis_mm2s_tlast(rbank_last),
    .m_ctrl_bank_rd_req(rd_req),.m_ctrl_bank_rd_grant(rd_grant),.m_ctrl_s2mm_adapter_start(wstart),
    .m_ctrl_s2mm_adapter_done(wdone),.m_ctrl_s2mm_adapter_abort(wabort_bank),.m_ctrl_s2mm_adapter_btt(wbtt_bank),
    .m_ctrl_s2mm_adapter_offset(woffset),.s_axis_s2mm_tdata(wbank_data),.s_axis_s2mm_tkeep(wbank_keep),
    .s_axis_s2mm_tvalid(wbank_valid),.s_axis_s2mm_tready(wbank_ready),.s_axis_s2mm_tlast(wbank_last));

  task automatic idle; begin
    rpause=0;rabort=0;rcpl_ready=0;rvalid=0;raddr=0;rbtt=0;roff=0;rbank=0;
    wpause=0;wabort=0;wcpl_ready=0;wvalid=0;waddr=0;wbtt=0;woff=0;wbank=0;
    rcmd_ready=0;rdata=0;rkeep=0;rdata_valid=0;rlast=0;rstatus=0;rstatus_keep=1;rstatus_valid=0;rstatus_last=1;
    wcmd_ready=0;wdata_ready=0;wstatus=0;wstatus_keep=1;wstatus_valid=0;wstatus_last=1;
    for(i=0;i<BANK_NUM;i=i+1) begin wr_grant[i]=1;rd_grant[i]=1;rdone[i]=0;wdone[i]=0;rbank_ready[i]=1;
      wbank_data[i]=64'h100+i;wbank_keep[i]=8'hff;wbank_valid[i]=0;wbank_last[i]=0;end
  end endtask
  task automatic reset; begin
    @(negedge aclk);aresetn=0;idle();repeat(4)@(posedge aclk);@(negedge aclk);aresetn=1;repeat(2)@(posedge aclk);
  end endtask
  task automatic wait_both_cmd; integer t; begin
    t=0;while(!(rcmd_valid&&wcmd_valid)&&t<20)begin @(posedge aclk);#1;t=t+1;end
    if(!(rcmd_valid&&wcmd_valid))$fatal(1,"simultaneous command timeout");
  end endtask

  initial begin
    aresetn=0;idle();reset();
    // Pause blocks acceptance. Once accepted, command valid/data persist through DMA backpressure.
    @(negedge aclk);rpause=1;wpause=1;
    raddr=32'h1000;rbtt=23'd32;roff=23'd64;rbank=1;rvalid=1;
    waddr=32'h2000;wbtt=23'd24;woff=23'd96;wbank=2;wvalid=1;
    repeat(3)begin @(posedge aclk);#1;if(rready||wready||rcmd_valid||wcmd_valid)$fatal(1,"pause accepted command");end
    @(negedge aclk);rpause=0;wpause=0;#1;if(!rready||!wready)$fatal(1,"unpause not ready");
    @(posedge aclk);#1;@(negedge aclk);rvalid=0;wvalid=0;
    wait_both_cmd();
    if(rcmd[67:64]!=0||rcmd[63:32]!=32'h1000||rcmd[30]!=1||rcmd[23]!=1||rcmd[22:0]!=32||
       wcmd[67:64]!=0||wcmd[63:32]!=32'h2000||wcmd[30]!=1||wcmd[23]!=1||wcmd[22:0]!=24)$fatal(1,"typed DMA command packing");
    begin logic[71:0] rh,wh;rh=rcmd;wh=wcmd;
      repeat(3)begin @(posedge aclk);#1;if(!rcmd_valid||!wcmd_valid||rcmd!==rh||wcmd!==wh)$fatal(1,"DMA command backpressure stability");end
    end
    @(negedge aclk);rcmd_ready=1;wcmd_ready=1;@(posedge aclk);#1;@(negedge aclk);rcmd_ready=0;wcmd_ready=0;
    repeat(2)@(posedge aclk);#1;
    if(!wr_req[1]||!rstart[1]||!rd_req[2]||!wstart[2]||roffset[1]!=64||wbtt_bank[2]!=24||woffset[2]!=96)
      $fatal(1,"per-bank adapter control routing");
    // Both directions independently finish; completion payload must hold under scheduler backpressure.
    @(negedge aclk);rdone[1]=1;wdone[2]=1;rstatus=8'h80;wstatus=8'h80;rstatus_valid=1;wstatus_valid=1;
    @(posedge aclk);#1;@(negedge aclk);rdone[1]=0;wdone[2]=0;rstatus_valid=0;wstatus_valid=0;
    begin integer t;t=0;while(!(rsts_valid&&wsts_valid)&&t<20)begin @(posedge aclk);#1;t=t+1;end
      if(!(rsts_valid&&wsts_valid))$fatal(1,"completion timeout");end
    repeat(3)begin @(posedge aclk);#1;if(!rsts_valid||!wsts_valid||rsts_code!=0||wsts_code!=0||rsts_bank!=1||wsts_bank!=2||rtag!=0||wtag!=0)$fatal(1,"completion backpressure stability");end
    @(negedge aclk);rcpl_ready=1;wcpl_ready=1;@(posedge aclk);#1;@(negedge aclk);rcpl_ready=0;wcpl_ready=0;
    $display("PROBE pause/typed-command/simultaneous-directions/adapter-routing/completion-hold PASS");

    // S2MM bad returned tag faults without retirement; explicit abort reaches only selected adapter.
    @(negedge aclk);waddr=32'h3000;wbtt=16;woff=128;wbank=0;wvalid=1;#1;
    if(!wready)$fatal(1,"second S2MM not ready");@(posedge aclk);#1;@(negedge aclk);wvalid=0;
    while(!wcmd_valid)begin @(posedge aclk);#1;end
    if(wcmd[67:64]!=1)$fatal(1,"S2MM tag ordering");
    @(negedge aclk);wcmd_ready=1;@(posedge aclk);#1;@(negedge aclk);wcmd_ready=0;
    repeat(2)@(posedge aclk);#1;
    @(negedge aclk);wstatus=8'h82;wstatus_valid=1;@(posedge aclk);#1;@(negedge aclk);wstatus_valid=0;
    while(!wsts_valid)begin @(posedge aclk);#1;end
    if(!wfault||wsts_code!=8'h20||wtag!=1||wrecv!=2||wsts_bank!=0||wabort_bank[0])$fatal(1,"S2MM tag mismatch diagnostics/autonomy");
    @(negedge aclk);wcpl_ready=1;@(posedge aclk);#1;@(negedge aclk);wcpl_ready=0;
    if(wready)$fatal(1,"fault accepted new command");
    @(negedge aclk);wabort=1;@(posedge aclk);#1;if(!wabort_bank[0]||wabort_bank[1]||wabort_bank[2])$fatal(1,"selected adapter abort routing");
    @(negedge aclk);wabort=0;
    $display("PROBE tag-mismatch/fault/head-retention/explicit-abort PASS");

    // Shared reset recovers, then invalid logical bank is retired locally and never issued.
    reset();
    @(negedge aclk);raddr=32'h4000;rbtt=8;roff=0;rbank=3;rvalid=1;#1;
    if(!rready)$fatal(1,"invalid descriptor not accepted for ordered response");@(posedge aclk);#1;@(negedge aclk);rvalid=0;
    repeat(5)begin @(posedge aclk);#1;
      if(rcmd_valid||wr_req[0]||wr_req[1]||wr_req[2])$fatal(1,"invalid bank reached DMA/adapter");
    end
    while(!rsts_valid)begin @(posedge aclk);#1;end
    if(rsts_code!=8'h04||!rsts_err||rsts_bank!=3||rfault)$fatal(1,"invalid-bank descriptor response");
    @(negedge aclk);rcpl_ready=1;@(posedge aclk);#1;@(negedge aclk);rcpl_ready=0;
    $display("PROBE reset-recovery/capability-table/descriptor-local-retire PASS");
    $display("DATAMOVER_ENGINE_INDEPENDENT_PROBE_PASS cases=3");
    $finish;
  end
  initial begin #20000;$fatal(1,"probe timeout");end
endmodule
