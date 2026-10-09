`timescale 1ns/1ps
module tb_s2mm_adapter;
  parameter integer BANK_WIDTH=64, STREAM_WIDTH=64, READ_LAT=1;
  localparam integer WORD_BYTES=BANK_WIDTH/8;
  logic clk=0, rstn=0, start=0, done, abort_req=0;
  logic [22:0] offset=0,btt=0;
  logic valid,ready=0,last,en;
  logic [STREAM_WIDTH-1:0] data;
  logic [STREAM_WIDTH/8-1:0] keep;
  logic [5:0] addr;
  logic [BANK_WIDTH-1:0] mempipe[READ_LAT];
  integer received=0, expected_bytes=0, expected_offset=0;
  logic checking=0;
  always #5 clk=~clk;
  // Common-clock memory model; en remains high while reads are outstanding.
  always @(posedge clk) if(en) begin
    for(integer j=0;j<WORD_BYTES;j=j+1)
      mempipe[0][j*8+:8] <= 8'(int'(addr)*WORD_BYTES+j);
    for(integer k=1;k<READ_LAT;k=k+1) mempipe[k]<=mempipe[k-1];
  end
  s2mm_adapter #(.S2MM_DATA_WIDTH(STREAM_WIDTH),.BANK_DOUTB_WIDTH(BANK_WIDTH),
    .BANK_ADDRB_WIDTH(6),.BANK_READ_LAT(READ_LAT)) dut(
    .aclk(clk),.aresetn(rstn),.s_ctrl_s2mm_adapter_start(start),
    .s_ctrl_s2mm_adapter_done(done),.s_ctrl_s2mm_adapter_abort(abort_req),
    .s_ctrl_s2mm_adapter_offset(offset),.s_ctrl_s2mm_adapter_btt(btt),
    .m_axis_s2mm_tdata(data),.m_axis_s2mm_tkeep(keep),.m_axis_s2mm_tvalid(valid),
    .m_axis_s2mm_tready(ready),.m_axis_s2mm_tlast(last),
    .bank_enb(en),.bank_addrb(addr),.bank_doutb(mempipe[READ_LAT-1]));
  logic stalled=0;
  logic [STREAM_WIDTH+STREAM_WIDTH/8:0] held;
  always @(posedge clk) begin
    if(rstn) begin
      if(stalled && (!valid || {last,keep,data}!==held))
        $fatal(1,"output changed under stall");
      stalled <= valid && !ready;
      held <= {last,keep,data};
      if(checking && valid && ready) begin
        for(integer j=0;j<STREAM_WIDTH/8;j=j+1) begin
          if(keep[j]) begin
            if(received>=expected_bytes || data[j*8+:8]!==8'(expected_offset+received))
              $fatal(1,"byte mismatch at %0d data=%h",received,data);
            received=received+1;
          end
        end
        if(last !== (received==expected_bytes)) $fatal(1,"TLAST mismatch");
      end
    end else stalled<=0;
  end
  task automatic run_job(input integer off, input integer len);
    @(negedge clk); offset=23'(off);btt=23'(len);start=1;
    expected_offset=off;expected_bytes=len;received=0;checking=1;
    fork
      begin
        for(integer n=0;n<500 && !done;n=n+1) begin
          @(negedge clk);ready=(n%5!=0 && n%5!=1);
        end
      end
      begin wait(done); end
    join
    if(!done || received!=len) $fatal(1,"incomplete job received=%0d",received);
    repeat(3) begin @(negedge clk);if(!done) $fatal(1,"done not held");end
    checking=0;start=0;ready=0;
    @(negedge clk);if(done) $fatal(1,"done not released");
  endtask
  initial begin
    repeat(3) @(negedge clk);rstn=1;
    run_job(0,8);run_job(WORD_BYTES,8);run_job(2*WORD_BYTES,13);
    run_job(0,1);run_job(WORD_BYTES,57);run_job(0,0);
    // Abort while output is stalled: preserve it until accepted, then rearm.
    @(negedge clk);offset=0;btt=23'd48;start=1;ready=0;
    wait(valid);@(negedge clk);abort_req=1;
    @(negedge clk);abort_req=0;
    repeat(4) begin @(negedge clk);if(done || !valid) $fatal(1,"premature abort");end
    ready=1;wait(done);@(negedge clk);start=0;ready=0;
    repeat(2) @(negedge clk);
    run_job(WORD_BYTES,17);
    $display("PASS s2mm bank=%0d stream=%0d latency=%0d offset/tail/stall/abort/rearm",BANK_WIDTH,STREAM_WIDTH,READ_LAT);
    $finish;
  end
  initial begin #100000; $fatal(1,"timeout");end
endmodule
