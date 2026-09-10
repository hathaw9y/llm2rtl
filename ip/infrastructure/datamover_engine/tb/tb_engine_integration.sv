`timescale 1ns/1ps
import datamover_engine_pkg::*;
module tb_engine_integration;
  parameter integer BANK_DATA_WIDTH=32, BANK_READ_LAT=1;
  localparam integer BANK_NUM=2, BANK_WIDTH=1;
  logic  clk = '0;
  logic  rstn = '0;
  logic  r_pause = '0;
  logic  r_abort = '0;
  logic  r_sts_ready = '0;
  wire  r_faulted;
  wire [3:0] r_sts_tag;
  wire [3:0] r_sts_received_tag;
  wire [7:0] r_sts_raw_status;
  logic  r_cmd_valid = '0;
  wire  r_cmd_ready;
  logic [ AXI_ADDR_WIDTH-1:0] r_cmd_addr = '0;
  logic [      BTT_WIDTH-1:0] r_cmd_btt = '0;
  logic [      BTT_WIDTH-1:0] r_cmd_offset = '0;
  logic [     BANK_WIDTH-1:0] r_cmd_bank = '0;
  wire  r_sts_valid;
  wire  r_sts_error;
  wire [                7:0] r_sts_error_code;
  wire [     BANK_WIDTH-1:0] r_sts_bank;
  logic  w_pause = '0;
  logic  w_abort = '0;
  logic  w_sts_ready = '0;
  wire  w_faulted;
  wire [3:0] w_sts_tag;
  wire [3:0] w_sts_received_tag;
  wire [7:0] w_sts_raw_status;
  logic  w_cmd_valid = '0;
  wire  w_cmd_ready;
  logic [ AXI_ADDR_WIDTH-1:0] w_cmd_addr = '0;
  logic [      BTT_WIDTH-1:0] w_cmd_btt = '0;
  logic [      BTT_WIDTH-1:0] w_cmd_offset = '0;
  logic [     BANK_WIDTH-1:0] w_cmd_bank = '0;
  wire  w_sts_valid;
  wire  w_sts_error;
  wire [                7:0] w_sts_error_code;
  wire [     BANK_WIDTH-1:0] w_sts_bank;
  wire [ CMD_DATA_WIDTH-1:0] r_dma_cmd_tdata;
  wire  r_dma_cmd_tvalid;
  logic  r_dma_cmd_tready = '0;
  logic [MM2S_DATA_WIDTH-1:0] r_dma_tdata = '0;
  logic [MM2S_KEEP_WIDTH-1:0] r_dma_tkeep = '0;
  logic  r_dma_tvalid = '0;
  wire  r_dma_tready;
  logic  r_dma_tlast = '0;
  logic [ STS_DATA_WIDTH-1:0] r_dma_sts_tdata = '0;
  logic [ STS_KEEP_WIDTH-1:0] r_dma_sts_tkeep = '0;
  logic  r_dma_sts_tvalid = '0;
  wire  r_dma_sts_tready;
  logic  r_dma_sts_tlast = '0;
  wire [ CMD_DATA_WIDTH-1:0] w_dma_cmd_tdata;
  wire  w_dma_cmd_tvalid;
  logic  w_dma_cmd_tready = '0;
  wire [S2MM_DATA_WIDTH-1:0] w_dma_tdata;
  wire [S2MM_KEEP_WIDTH-1:0] w_dma_tkeep;
  wire  w_dma_tvalid;
  logic  w_dma_tready = '0;
  wire  w_dma_tlast;
  logic [ STS_DATA_WIDTH-1:0] w_dma_sts_tdata = '0;
  logic [ STS_KEEP_WIDTH-1:0] w_dma_sts_tkeep = '0;
  logic  w_dma_sts_tvalid = '0;
  wire  w_dma_sts_tready;
  logic  w_dma_sts_tlast = '0;
  wire  wr_req[BANK_NUM];
  wire  wr_grant[BANK_NUM];
  wire  r_adapter_start[BANK_NUM];
  wire  r_adapter_done[BANK_NUM];
  wire  r_adapter_abort[BANK_NUM];
  wire [      BTT_WIDTH-1:0] r_adapter_offset[BANK_NUM];
  wire [MM2S_DATA_WIDTH-1:0] r_bank_tdata[BANK_NUM];
  wire [MM2S_KEEP_WIDTH-1:0] r_bank_tkeep[BANK_NUM];
  wire  r_bank_tvalid[BANK_NUM];
  wire  r_bank_tready[BANK_NUM];
  wire  r_bank_tlast[BANK_NUM];
  wire  rd_req[BANK_NUM];
  wire  rd_grant[BANK_NUM];
  wire  w_adapter_start[BANK_NUM];
  wire  w_adapter_done[BANK_NUM];
  wire  w_adapter_abort[BANK_NUM];
  wire [      BTT_WIDTH-1:0] w_adapter_btt[BANK_NUM];
  wire [      BTT_WIDTH-1:0] w_adapter_offset[BANK_NUM];
  wire [S2MM_DATA_WIDTH-1:0] w_bank_tdata[BANK_NUM];
  wire [S2MM_KEEP_WIDTH-1:0] w_bank_tkeep[BANK_NUM];
  wire  w_bank_tvalid[BANK_NUM];
  wire  w_bank_tready[BANK_NUM];
  wire  w_bank_tlast[BANK_NUM];
  logic contend=0, inject_bad_tag=0;
  wire native_write[BANK_NUM];
  logic [7:0] ddr[8192];
  integer cycle=0, overlap_cycles=0;
  always #5 clk=~clk;
  datamover_engine #(.BANK_NUM(BANK_NUM),
    .BANK_WORD_BYTES({BANK_NUM{32'(BANK_DATA_WIDTH/8)}}),
    .BANK_CAPACITY_BYTES({BANK_NUM{32'(64*BANK_DATA_WIDTH/8)}})) dut(
    .aclk(clk),
    .aresetn(rstn),
    .s_ctrl_mm2s_pause(r_pause),
    .s_ctrl_mm2s_abort(r_abort),
    .m_ctrl_mm2s_sts_ready(r_sts_ready),
    .m_ctrl_mm2s_faulted(r_faulted),
    .m_ctrl_mm2s_sts_tag(r_sts_tag),
    .m_ctrl_mm2s_sts_received_tag(r_sts_received_tag),
    .m_ctrl_mm2s_sts_raw_status(r_sts_raw_status),
    .s_ctrl_mm2s_cmd_valid(r_cmd_valid),
    .s_ctrl_mm2s_cmd_ready(r_cmd_ready),
    .s_ctrl_mm2s_cmd_addr(r_cmd_addr),
    .s_ctrl_mm2s_cmd_btt(r_cmd_btt),
    .s_ctrl_mm2s_cmd_offset(r_cmd_offset),
    .s_ctrl_mm2s_cmd_bank(r_cmd_bank),
    .m_ctrl_mm2s_sts_valid(r_sts_valid),
    .m_ctrl_mm2s_sts_error(r_sts_error),
    .m_ctrl_mm2s_sts_error_code(r_sts_error_code),
    .m_ctrl_mm2s_sts_bank(r_sts_bank),
    .s_ctrl_s2mm_pause(w_pause),
    .s_ctrl_s2mm_abort(w_abort),
    .m_ctrl_s2mm_sts_ready(w_sts_ready),
    .m_ctrl_s2mm_faulted(w_faulted),
    .m_ctrl_s2mm_sts_tag(w_sts_tag),
    .m_ctrl_s2mm_sts_received_tag(w_sts_received_tag),
    .m_ctrl_s2mm_sts_raw_status(w_sts_raw_status),
    .s_ctrl_s2mm_cmd_valid(w_cmd_valid),
    .s_ctrl_s2mm_cmd_ready(w_cmd_ready),
    .s_ctrl_s2mm_cmd_addr(w_cmd_addr),
    .s_ctrl_s2mm_cmd_btt(w_cmd_btt),
    .s_ctrl_s2mm_cmd_offset(w_cmd_offset),
    .s_ctrl_s2mm_cmd_bank(w_cmd_bank),
    .m_ctrl_s2mm_sts_valid(w_sts_valid),
    .m_ctrl_s2mm_sts_error(w_sts_error),
    .m_ctrl_s2mm_sts_error_code(w_sts_error_code),
    .m_ctrl_s2mm_sts_bank(w_sts_bank),
    .m_axis_mm2s_cmd_tdata(r_dma_cmd_tdata),
    .m_axis_mm2s_cmd_tvalid(r_dma_cmd_tvalid),
    .m_axis_mm2s_cmd_tready(r_dma_cmd_tready),
    .s_axis_mm2s_tdata(r_dma_tdata),
    .s_axis_mm2s_tkeep(r_dma_tkeep),
    .s_axis_mm2s_tvalid(r_dma_tvalid),
    .s_axis_mm2s_tready(r_dma_tready),
    .s_axis_mm2s_tlast(r_dma_tlast),
    .s_axis_mm2s_sts_tdata(r_dma_sts_tdata),
    .s_axis_mm2s_sts_tkeep(r_dma_sts_tkeep),
    .s_axis_mm2s_sts_tvalid(r_dma_sts_tvalid),
    .s_axis_mm2s_sts_tready(r_dma_sts_tready),
    .s_axis_mm2s_sts_tlast(r_dma_sts_tlast),
    .m_axis_s2mm_cmd_tdata(w_dma_cmd_tdata),
    .m_axis_s2mm_cmd_tvalid(w_dma_cmd_tvalid),
    .m_axis_s2mm_cmd_tready(w_dma_cmd_tready),
    .m_axis_s2mm_tdata(w_dma_tdata),
    .m_axis_s2mm_tkeep(w_dma_tkeep),
    .m_axis_s2mm_tvalid(w_dma_tvalid),
    .m_axis_s2mm_tready(w_dma_tready),
    .m_axis_s2mm_tlast(w_dma_tlast),
    .s_axis_s2mm_sts_tdata(w_dma_sts_tdata),
    .s_axis_s2mm_sts_tkeep(w_dma_sts_tkeep),
    .s_axis_s2mm_sts_tvalid(w_dma_sts_tvalid),
    .s_axis_s2mm_sts_tready(w_dma_sts_tready),
    .s_axis_s2mm_sts_tlast(w_dma_sts_tlast),
    .m_ctrl_bank_wr_req(wr_req),
    .m_ctrl_bank_wr_grant(wr_grant),
    .m_ctrl_mm2s_adapter_start(r_adapter_start),
    .m_ctrl_mm2s_adapter_done(r_adapter_done),
    .m_ctrl_mm2s_adapter_abort(r_adapter_abort),
    .m_ctrl_mm2s_adapter_offset(r_adapter_offset),
    .m_axis_mm2s_tdata(r_bank_tdata),
    .m_axis_mm2s_tkeep(r_bank_tkeep),
    .m_axis_mm2s_tvalid(r_bank_tvalid),
    .m_axis_mm2s_tready(r_bank_tready),
    .m_axis_mm2s_tlast(r_bank_tlast),
    .m_ctrl_bank_rd_req(rd_req),
    .m_ctrl_bank_rd_grant(rd_grant),
    .m_ctrl_s2mm_adapter_start(w_adapter_start),
    .m_ctrl_s2mm_adapter_done(w_adapter_done),
    .m_ctrl_s2mm_adapter_abort(w_adapter_abort),
    .m_ctrl_s2mm_adapter_btt(w_adapter_btt),
    .m_ctrl_s2mm_adapter_offset(w_adapter_offset),
    .s_axis_s2mm_tdata(w_bank_tdata),
    .s_axis_s2mm_tkeep(w_bank_tkeep),
    .s_axis_s2mm_tvalid(w_bank_tvalid),
    .s_axis_s2mm_tready(w_bank_tready),
    .s_axis_s2mm_tlast(w_bank_tlast));
  for(genvar b=0;b<BANK_NUM;b=b+1) begin: banks
    integration_bank #(.WIDTH(BANK_DATA_WIDTH),.LATENCY(BANK_READ_LAT)) bank(
      .clk(clk),.rstn(rstn),.contend(contend),
      .wr_req(wr_req[b]),.rd_req(rd_req[b]),.wr_grant(wr_grant[b]),.rd_grant(rd_grant[b]),
      .wr_start(r_adapter_start[b]),.rd_start(w_adapter_start[b]),
      .wr_abort(r_adapter_abort[b]),.rd_abort(w_adapter_abort[b]),
      .wr_done(r_adapter_done[b]),.rd_done(w_adapter_done[b]),
      .wr_offset(r_adapter_offset[b]),.rd_offset(w_adapter_offset[b]),.rd_btt(w_adapter_btt[b]),
      .wr_data(r_bank_tdata[b]),.wr_keep(r_bank_tkeep[b]),.wr_valid(r_bank_tvalid[b]),
      .wr_ready(r_bank_tready[b]),.wr_last(r_bank_tlast[b]),
      .rd_data(w_bank_tdata[b]),.rd_keep(w_bank_tkeep[b]),.rd_valid(w_bank_tvalid[b]),
      .rd_ready(w_bank_tready[b]),.rd_last(w_bank_tlast[b]),.native_write(native_write[b]));
  end
  // Behavioral DataMover: direction-local command queues, INCR byte copies,
  // deterministic stalls, ordered status. Not vendor IP or an AXI-MM model.
  logic [71:0] rq[128],wq[128];
  integer rtail=0,rhead=0,wtail=0,whead=0,rs=0,ws=0;
  integer ra=0,rlen=0,rpos=0,wa=0,wlen=0,wpos=0;
  logic [3:0] rtag=0,wtag=0;
  always @(posedge clk) begin
    if(!rstn) begin
      cycle<=0;rtail=0;rhead=0;wtail=0;whead=0;rs=0;ws=0;
      r_dma_cmd_tready<=0;w_dma_cmd_tready<=0;
      r_dma_tvalid<=0;r_dma_tdata<=0;r_dma_tkeep<=0;r_dma_tlast<=0;
      r_dma_sts_tvalid<=0;w_dma_sts_tvalid<=0;w_dma_tready<=0;
      r_dma_sts_tkeep<=1;w_dma_sts_tkeep<=1;r_dma_sts_tlast<=1;w_dma_sts_tlast<=1;
      overlap_cycles<=0;
    end else begin
      cycle<=cycle+1;
      r_dma_cmd_tready <= (cycle%5!=0);
      w_dma_cmd_tready <= (cycle%7!=0);
      if(r_dma_cmd_tvalid && r_dma_cmd_tready) begin
        if(rtail>=128) $fatal(1,"read model command overflow");
        rq[rtail]=r_dma_cmd_tdata;rtail=rtail+1;
      end
      if(w_dma_cmd_tvalid && w_dma_cmd_tready) begin
        if(wtail>=128) $fatal(1,"write model command overflow");
        wq[wtail]=w_dma_cmd_tdata;wtail=wtail+1;
      end
      if(rs!=0 && ws!=0) overlap_cycles<=overlap_cycles+1;
      case(rs)
        0: if(rhead<rtail) begin
          ra=int'(rq[rhead][63:32]);rlen=int'(rq[rhead][22:0]);rtag=rq[rhead][67:64];
          if(ra<0 || ra+rlen>8192 || rlen==0 || rq[rhead][23]!==1'b1 || rq[rhead][30]!==1'b1)
            $fatal(1,"bad MM2S descriptor reached model");
          rhead=rhead+1;rpos=0;
          if(inject_bad_tag) begin
            r_dma_sts_tdata<={4'h8,rtag+4'd1};r_dma_sts_tvalid<=1;rs=2;
          end else rs=1;
        end
        1: begin
          if(r_dma_tvalid && r_dma_tready) begin
            r_dma_tvalid<=0;
            if(r_dma_tlast) begin
              r_dma_sts_tvalid<=1;r_dma_sts_tdata<={4'h8,rtag};rs=2;
            end
          end
          if(!r_dma_tvalid && cycle%3!=0) begin
            for(integer j=0;j<8;j=j+1) begin
              r_dma_tdata[j*8+:8]<=(rpos+j<rlen)?ddr[ra+rpos+j]:8'd0;
              r_dma_tkeep[j]<=(rpos+j<rlen);
            end
            r_dma_tlast<=(rpos+8>=rlen);r_dma_tvalid<=1;rpos=rpos+8;
          end
        end
        2: if(r_dma_sts_tvalid && r_dma_sts_tready) begin r_dma_sts_tvalid<=0;rs=0;end
      endcase
      w_dma_tready <= (ws==1 && cycle%4!=0 && cycle%4!=1);
      case(ws)
        0: if(whead<wtail) begin
          wa=int'(wq[whead][63:32]);wlen=int'(wq[whead][22:0]);wtag=wq[whead][67:64];
          if(wa<0 || wa+wlen>8192 || wlen==0 || wq[whead][23]!==1'b1 || wq[whead][30]!==1'b1)
            $fatal(1,"bad S2MM descriptor reached model");
          whead=whead+1;wpos=0;ws=1;
        end
        1: if(w_dma_tvalid && w_dma_tready) begin
          for(integer j=0;j<8;j=j+1) begin
            if(w_dma_tkeep[j] !== (wpos<wlen)) $fatal(1,"write keep mismatch");
            if(w_dma_tkeep[j]) begin ddr[wa+wpos]=w_dma_tdata[j*8+:8];wpos=wpos+1;end
          end
          if(w_dma_tlast !== (wpos==wlen)) $fatal(1,"write last/length mismatch");
          if(w_dma_tlast) begin
            w_dma_tready<=0;w_dma_sts_tvalid<=1;w_dma_sts_tdata<={4'h8,wtag};ws=2;
          end
        end
        2: if(w_dma_sts_tvalid && w_dma_sts_tready) begin w_dma_sts_tvalid<=0;ws=0;end
      endcase
    end
  end
  // Protocol monitors sample actual public ports, not internal FSM state.
  logic [5:0] held_valid=0;
  logic [71:0] held_rd_cmd,held_wr_cmd;
  logic [72:0] held_read,held_write;
  logic [25:0] held_rc,held_wc;
  always @(posedge clk) begin
    if(!rstn) held_valid<=0;
    else begin
      if(held_valid[0] && (!r_dma_cmd_tvalid || r_dma_cmd_tdata!==held_rd_cmd)) $fatal(1,"read command stall");
      if(held_valid[1] && (!w_dma_cmd_tvalid || w_dma_cmd_tdata!==held_wr_cmd)) $fatal(1,"write command stall");
      if(held_valid[2] && (!r_dma_tvalid || {r_dma_tlast,r_dma_tkeep,r_dma_tdata}!==held_read)) $fatal(1,"read stream stall");
      if(held_valid[3] && (!w_dma_tvalid || {w_dma_tlast,w_dma_tkeep,w_dma_tdata}!==held_write)) $fatal(1,"write stream stall");
      if(held_valid[4] && (!r_sts_valid || {r_sts_bank,r_sts_tag,r_sts_received_tag,r_sts_error_code,r_sts_raw_status}!==held_rc)) $fatal(1,"read completion stall");
      if(held_valid[5] && (!w_sts_valid || {w_sts_bank,w_sts_tag,w_sts_received_tag,w_sts_error_code,w_sts_raw_status}!==held_wc)) $fatal(1,"write completion stall");
      held_valid<={w_sts_valid&&!w_sts_ready,r_sts_valid&&!r_sts_ready,w_dma_tvalid&&!w_dma_tready,
                   r_dma_tvalid&&!r_dma_tready,w_dma_cmd_tvalid&&!w_dma_cmd_tready,r_dma_cmd_tvalid&&!r_dma_cmd_tready};
      held_rd_cmd<=r_dma_cmd_tdata;held_wr_cmd<=w_dma_cmd_tdata;
      held_read<={r_dma_tlast,r_dma_tkeep,r_dma_tdata};held_write<={w_dma_tlast,w_dma_tkeep,w_dma_tdata};
      held_rc<={r_sts_bank,r_sts_tag,r_sts_received_tag,r_sts_error_code,r_sts_raw_status};
      held_wc<={w_sts_bank,w_sts_tag,w_sts_received_tag,w_sts_error_code,w_sts_raw_status};
    end
  end
  // Scheduler BFM is the ONLY source of engine control commands and recovery.
  task automatic issue_read(input integer a,n,o,b);
    $display("scheduler read addr=%0d bytes=%0d offset=%0d bank=%0d",a,n,o,b);
    @(negedge clk);r_cmd_addr=32'(a);r_cmd_btt=23'(n);r_cmd_offset=23'(o);r_cmd_bank=1'(b);r_cmd_valid=1;
    do @(posedge clk);while(!r_cmd_ready);
    @(negedge clk);r_cmd_valid=0;
  endtask
  task automatic issue_write(input integer a,n,o,b);
    $display("scheduler write addr=%0d bytes=%0d offset=%0d bank=%0d",a,n,o,b);
    @(negedge clk);w_cmd_addr=32'(a);w_cmd_btt=23'(n);w_cmd_offset=23'(o);w_cmd_bank=1'(b);w_cmd_valid=1;
    do @(posedge clk);while(!w_cmd_ready);
    @(negedge clk);w_cmd_valid=0;
  endtask
  task automatic complete_read(input logic [7:0] code,input integer tag,b);
    wait(r_sts_valid);@(negedge clk);
    if(r_sts_error_code!==code || r_sts_tag!==4'(tag) || r_sts_bank!==1'(b)) $fatal(1,"read response mismatch");
    repeat(5) @(negedge clk);
    r_sts_ready=1;@(negedge clk);r_sts_ready=0;
  endtask
  task automatic complete_write(input logic [7:0] code,input integer tag,b);
    wait(w_sts_valid);@(negedge clk);
    if(w_sts_error_code!==code || w_sts_tag!==4'(tag) || w_sts_bank!==1'(b)) $fatal(1,"write response mismatch");
    repeat(5) @(negedge clk);
    w_sts_ready=1;@(negedge clk);w_sts_ready=0;
  endtask
  task automatic compare_copy(input integer src,dst,n);
    for(integer j=0;j<n;j=j+1) if(ddr[dst+j]!==ddr[src+j]) $fatal(1,"DDR byte mismatch src=%0d dst=%0d byte=%0d",src,dst,j);
    if(ddr[dst-1]!==8'hee || ddr[dst+n]!==8'hee) $fatal(1,"DDR guard overwritten");
  endtask
  task automatic reset_system;
    @(negedge clk);rstn=0;r_cmd_valid=0;w_cmd_valid=0;r_sts_ready=0;w_sts_ready=0;
    r_abort=0;w_abort=0;r_pause=0;w_pause=0;contend=0;inject_bad_tag=0;
    repeat(5) @(negedge clk);rstn=1;repeat(3) @(negedge clk);
  endtask
  initial begin
    for(integer i=0;i<8192;i=i+1) ddr[i]=8'hee;
    for(integer i=0;i<1024;i=i+1) ddr[i]=8'((i*37+19)^(i>>3));
    reset_system();
    // Competing client owns both bank ports; engine must wait for release.
    contend=1;repeat(4) @(negedge clk);
    issue_read(0,13,32,0);issue_read(128,29,64,0);
    repeat(12) begin @(negedge clk);if(native_write[0] || native_write[1]) $fatal(1,"bank reservation ignored");end
    contend=0;
    complete_read(0,0,0);complete_read(0,1,0);
    issue_write(2048,13,32,0);complete_write(0,0,0);compare_copy(0,2048,13);
    issue_write(2176,29,64,0);complete_write(0,1,0);compare_copy(128,2176,29);
    // Independent-bank simultaneous read and write.
    fork
      begin issue_read(256,57,32,1);complete_read(0,2,1);end
      begin issue_write(2304,29,64,0);complete_write(0,2,0);end
    join
    if(overlap_cycles==0) $fatal(1,"no simultaneous direction activity");
    compare_copy(128,2304,29);
    issue_write(2432,57,32,1);complete_write(0,3,1);compare_copy(256,2432,57);
    // Rejected command must not reach DataMover or modify bank contents.
    begin integer before_count;before_count=rtail;
      issue_read(3,8,0,0);complete_read(8'h02,3,0);
      if(rtail!=before_count) $fatal(1,"invalid descriptor reached DataMover");
    end
    issue_write(2560,13,32,0);complete_write(0,4,0);compare_copy(0,2560,13);
    // Error before payload: engine reports, scheduler chooses abort + reset.
    inject_bad_tag=1;issue_read(512,16,0,1);
    wait(r_sts_valid);@(negedge clk);
    if(!r_faulted || r_sts_received_tag!==4'd5 || r_sts_tag!==4'd4) $fatal(1,"missing fault diagnostics");
    repeat(5) begin @(negedge clk);if(r_adapter_abort[0] || r_adapter_abort[1]) $fatal(1,"engine autonomously aborted");end
    complete_read(8'h20,4,1);
    if(r_cmd_ready) $fatal(1,"fault allowed new command");
    @(negedge clk);r_abort=1;
    wait(r_adapter_abort[1]);@(negedge clk);r_abort=0;
    // Board controller resets engine, DataMover model and adapters together.
    reset_system();
    issue_read(640,17,32,0);complete_read(0,0,0);
    issue_write(2688,17,32,0);complete_write(0,0,0);compare_copy(640,2688,17);
    $display("PASS integration scheduler/engine/adapters/arbiter DDR-copy queued same-bank contention concurrency rejection fault scheduler-reset bank=%0d latency=%0d",BANK_DATA_WIDTH,BANK_READ_LAT);
    $finish;
  end
  initial begin #500000;
    $display("timeout rq=%0d/%0d rs=%0d payload=%b/%b req=%b grant=%b start=%b done=%b bankvalid=%b bankready=%b completion=%b code=%h",
      rhead,rtail,rs,r_dma_tvalid,r_dma_tready,wr_req[0],wr_grant[0],r_adapter_start[0],r_adapter_done[0],r_bank_tvalid[0],r_bank_tready[0],r_sts_valid,r_sts_error_code);
    $fatal(1,"integration timeout");end
endmodule
