`timescale 1ns/1ps
module tb_registered_capture #(
    parameter int DATA_WIDTH = 32,
    parameter int GROUP_WIDTH = 32,
    parameter bit USE_XILINX_FDRE = 1'b1
);
  logic aclk = 0;
  always #2.5 aclk = !aclk;
  logic aresetn = 0, capture_i = 0;
  logic [DATA_WIDTH-1:0] data_i = '0;
  wire [DATA_WIDTH-1:0] data_o;
  wire valid_o;
  registered_capture #(.DATA_WIDTH(DATA_WIDTH), .GROUP_WIDTH(GROUP_WIDTH),
      .USE_XILINX_FDRE(USE_XILINX_FDRE)) dut (.*);
  wire [135:0] example_o;
  wire example_valid;
  logic [135:0] example_i = '0;
  registered_capture_example #(.USE_XILINX_FDRE(USE_XILINX_FDRE)) example (
      .aclk(aclk), .aresetn(aresetn), .accepted_i(capture_i),
      .payload_i(example_i[63:0]), .mask_i(example_i[71:64]),
      .index_i(example_i[87:72]), .transaction_i(example_i[119:88]),
      .generation_i(example_i[135:120]), .valid_o(example_valid),
      .payload_o(example_o[63:0]), .mask_o(example_o[71:64]),
      .index_o(example_o[87:72]), .transaction_o(example_o[119:88]),
      .generation_o(example_o[135:120]));
  logic pending = 0;
  logic [DATA_WIDTH-1:0] pending_data = '0, expected_data = '0;
  logic [135:0] pending_example = '0, expected_example = '0;
  bit expected_valid;
  int accepted_count = 0, emitted_count = 0, bubble_count = 0;
  int reset_ce0 = 0, reset_ce1 = 0, cycles = 0;
  task automatic step(input bit rst_n, input bit accept, input bit ones);
    @(negedge aclk);
    aresetn = rst_n;
    capture_i = accept;
    for (int b = 0; b < DATA_WIDTH; b++) data_i[b] = ones ? 1'b1 : $urandom_range(0,1);
    for (int b = 0; b < 136; b++) example_i[b] = ones ? 1'b1 : $urandom_range(0,1);
    @(posedge aclk);
    if (!rst_n) begin
      if (pending) reset_ce1++; else reset_ce0++;
      expected_data = '0; expected_example = '0; expected_valid = 0;
      pending = 0; pending_data = '0; pending_example = '0;
    end else begin
      expected_valid = pending;
      if (pending) begin
        expected_data = pending_data; expected_example = pending_example;
        emitted_count++;
      end else bubble_count++;
      pending = accept; pending_data = data_i; pending_example = example_i;
      if (accept) accepted_count++;
    end
    #0.1;
    if (valid_o !== expected_valid || data_o !== expected_data)
      $fatal(1, "capture mismatch cycle=%0d width=%0d backend=%0d", cycles, DATA_WIDTH, USE_XILINX_FDRE);
    if (example_valid !== expected_valid || example_o !== expected_example)
      $fatal(1, "opaque metadata example mismatch cycle=%0d", cycles);
    cycles++;
    // Change live packet and event after the acceptance edge, before E1.
    #0.2; data_i = ~data_i; example_i = ~example_i; capture_i = !capture_i;
  endtask
  initial begin
    // Real unisim glbl GSR startup is 100ns. Drive reset through startup.
    #120;
    step(0,0,0); step(1,1,1); step(1,0,0); // seed held output all ones
    step(0,1,0); step(1,0,0); // reset CE=0 and capture overlap
    step(1,1,1); step(0,1,0); step(0,0,0); step(1,0,0); // reset pending CE=1
    for (int i = 0; i < 80; i++) step(1,1,0); // II=1
    for (int i = 0; i < 240; i++) step(1,(i%5 != 0 && i%7 != 0),0);
    for (int i = 0; i < 20; i++) begin
      step(1,1,0); step(0,1,0); step(1,0,0); step(1,0,0);
    end
    step(1,0,0); step(1,0,0);
    if (reset_ce0 == 0 || reset_ce1 == 0 || emitted_count < 100 || bubble_count < 30)
      $fatal(1, "coverage missing");
    $display("COVERAGE accepted=%0d emitted=%0d bubbles=%0d reset_ce0=%0d reset_ce1=%0d cycles=%0d", accepted_count, emitted_count, bubble_count, reset_ce0, reset_ce1, cycles);
    $display("PASS registered_capture width=%0d group=%0d backend=%0d", DATA_WIDTH, GROUP_WIDTH, USE_XILINX_FDRE);
    $finish;
  end
endmodule
