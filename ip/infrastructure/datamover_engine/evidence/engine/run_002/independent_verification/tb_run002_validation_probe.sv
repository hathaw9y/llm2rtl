`timescale 1ns/1ps
module tb_run002_validation_probe;
  logic clk=0, rstn=0, pause=0, abort_req=0;
  logic cmd_valid=0, cmd_ready;
  logic [31:0] cmd_addr=0;
  logic [22:0] cmd_btt=0, cmd_offset=0;
  logic [1:0] cmd_bank=0;
  logic dma_valid, dma_ready=0;
  logic [71:0] dma_data;
  logic status_valid=0, status_ready, status_keep=1, status_last=1;
  logic [7:0] status_data=0;
  logic head_active, adapter_done=0, adapter_finished;
  logic [1:0] head_bank, completion_bank;
  logic [22:0] head_offset, head_btt;
  logic completion_valid, completion_ready=0, faulted;
  logic [3:0] completion_tag, completion_received_tag;
  logic [7:0] completion_code, completion_raw_status;
  logic [71:0] held;
  int dma_valid_cycles;

  always #5 clk=~clk;
  always @(posedge clk) if (rstn && dma_valid) dma_valid_cycles++;

  datamover_command_queue #(
    .BANK_NUM(3), .DEPTH(4), .DDR_ALIGN_BYTES(8),
    .BANK_WORD_BYTES({32'd16,32'd8,32'd8}),
    .BANK_CAPACITY_BYTES({32'd32,32'd64,32'd64})
  ) dut (
    .aclk(clk), .aresetn(rstn), .pause(pause), .scheduler_abort(abort_req),
    .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_addr(cmd_addr),
    .cmd_btt(cmd_btt), .cmd_offset(cmd_offset), .cmd_bank(cmd_bank),
    .dma_cmd_valid(dma_valid), .dma_cmd_ready(dma_ready), .dma_cmd_data(dma_data),
    .status_valid(status_valid), .status_ready(status_ready), .status_data(status_data),
    .status_keep(status_keep), .status_last(status_last),
    .head_active(head_active), .head_bank(head_bank), .head_offset(head_offset),
    .head_btt(head_btt), .adapter_done(adapter_done), .adapter_finished(adapter_finished),
    .completion_valid(completion_valid), .completion_ready(completion_ready),
    .completion_bank(completion_bank), .completion_tag(completion_tag),
    .completion_received_tag(completion_received_tag), .completion_code(completion_code),
    .completion_raw_status(completion_raw_status), .faulted(faulted)
  );

  task automatic reset_dut;
    @(negedge clk);
    rstn=0; pause=0; abort_req=0; cmd_valid=0; dma_ready=0;
    status_valid=0; status_keep=1; status_last=1; adapter_done=0;
    completion_ready=0; dma_valid_cycles=0;
    repeat(3) @(negedge clk);
    rstn=1;
    @(negedge clk);
  endtask

  task automatic send_cmd(input logic [31:0] a, input logic [22:0] n,
                          input logic [22:0] o, input logic [1:0] b);
    cmd_addr=a; cmd_btt=n; cmd_offset=o; cmd_bank=b; cmd_valid=1;
    do @(posedge clk); while(!cmd_ready);
    @(negedge clk); cmd_valid=0;
  endtask

  task automatic expect_reject(input logic [31:0] a, input logic [22:0] n,
                               input logic [22:0] o, input logic [1:0] b,
                               input logic [7:0] expected);
    reset_dut();
    send_cmd(a,n,o,b);
    repeat(12) begin
      @(negedge clk);
      if(dma_valid) $fatal(1,"invalid descriptor reached DMA code=%02x",expected);
      if(completion_valid) begin
        if(completion_code!==expected) $fatal(1,"precedence expected=%02x got=%02x",expected,completion_code);
        completion_ready=1; @(negedge clk); completion_ready=0;
        return;
      end
    end
    $fatal(1,"missing descriptor completion code=%02x",expected);
  endtask

  initial begin
    // Every pair deliberately violates multiple lower-priority conditions.
    expect_reject(32'h3,0,8,3,8'h01);
    expect_reject(32'h3,8,8,3,8'h02);
    expect_reject(32'hfffffff8,16,8,3,8'h03);
    expect_reject(0,8,8,3,8'h04);
    expect_reject(0,32,8,2,8'h05);
    expect_reject(0,40,16,2,8'h06);
    $display("PROBE descriptor precedence 01>02>03>04>05>06 PASS");

    // Accepted command proceeds through validation despite later pause, and its
    // DMA payload remains stable while ready is low.
    reset_dut();
    send_cmd(32'h100,16,16,2);
    pause=1;
    wait(dma_valid);
    held=dma_data;
    repeat(4) begin @(negedge clk); if(!dma_valid || dma_data!==held) $fatal(1,"DMA command unstable under pause/backpressure"); end
    if(dma_valid_cycles<3) $fatal(1,"insufficient DMA stall observation");
    pause=0; dma_ready=1; @(negedge clk); dma_ready=0;
    wait(head_active);
    if(head_bank!=2 || head_offset!=16 || head_btt!=16) $fatal(1,"typed metadata changed across validation pipeline");
    adapter_done=1; status_valid=1; status_data=8'h80; @(negedge clk);
    adapter_done=0; status_valid=0;
    wait(completion_valid);
    if(completion_code!=0 || completion_bank!=2) $fatal(1,"legal completion mismatch");
    completion_ready=1; @(negedge clk); completion_ready=0;
    $display("PROBE staged validation/pause/DMA stability PASS");

    // Once a good status and adapter completion are presented, a simultaneous
    // scheduler abort must still produce a held diagnostic response (50) or a
    // previously completed success. It must not enter faulted state silently.
    reset_dut();
    dma_ready=1;
    send_cmd(32'h200,16,0,1);
    wait(head_active);
    @(negedge clk);
    adapter_done=1; status_valid=1; status_data=8'h80; abort_req=1;
    @(negedge clk);
    adapter_done=0; status_valid=0; abort_req=0; dma_ready=0;
    repeat(8) begin
      @(negedge clk);
      if(completion_valid) begin
        if(completion_code!==8'h50 && completion_code!==8'h00)
          $fatal(1,"unexpected simultaneous status/abort completion %02x",completion_code);
        $display("PROBE simultaneous status/abort response PASS code=%02x",completion_code);
        $display("DATAMOVER_RUN002_VALIDATION_PROBE_PASS");
        $finish;
      end
    end
    $fatal(1,"faulted without completion after simultaneous good status and scheduler abort; faulted=%0d head_active=%0d",faulted,head_active);
  end

  initial begin #100000; $fatal(1,"timeout"); end
endmodule
