`timescale 1ns/1ps
// Independent byte-addressed memory model and read-request delay queue.
// Expected read bytes are sampled before applying writes (read_first).
module tb_smollm2_striped_weight_bank;
  parameter integer PORT_COUNT = 4;
  parameter integer PORT_DATA_WIDTH = 128;
  parameter integer DEPTH = 16;
  parameter integer READ_LATENCY = 3;
  parameter integer ADDR_WIDTH = 32;
  localparam integer BYTE_COUNT = PORT_DATA_WIDTH/8;
  localparam integer OUT_WIDTH = PORT_COUNT*PORT_DATA_WIDTH;
  logic aclk = 1'b0;
  logic aresetn = 1'b0;
  logic clear_commit_i = 1'b0;
  logic [PORT_COUNT-1:0] ena_i = '0;
  logic [ADDR_WIDTH-1:0] addra_i [PORT_COUNT];
  logic [PORT_DATA_WIDTH-1:0] dina_i [PORT_COUNT];
  logic [BYTE_COUNT-1:0] wea_i [PORT_COUNT];
  logic enb_i = 1'b0;
  logic [ADDR_WIDTH-1:0] addrb_i = '0;
  logic [OUT_WIDTH-1:0] doutb_o;
  logic [ADDR_WIDTH:0] commitb_o;
  logic [PORT_COUNT-1:0] wr_address_error_o;
  logic rd_address_error_o;
  byte unsigned reference_bytes [PORT_COUNT][DEPTH][BYTE_COUNT];
  integer reference_prefix [PORT_COUNT];
  logic [OUT_WIDTH-1:0] read_queue [READ_LATENCY];
  bit read_pending [READ_LATENCY];
  logic [OUT_WIDTH-1:0] expected_output = '0;
  integer checks = 0;
  integer read_checks = 0;
  integer accepted_writes = 0;
  integer cycles = 0;

  smollm2_striped_weight_bank #(
      .PORT_COUNT(PORT_COUNT), .PORT_DATA_WIDTH(PORT_DATA_WIDTH),
      .DEPTH(DEPTH), .READ_LATENCY(READ_LATENCY), .ADDR_WIDTH(ADDR_WIDTH)
  ) dut (.*);
  always #2.5 aclk = ~aclk;

  task automatic check(input bit condition, input string label);
    checks++;
    if (!condition) $fatal(1, "CHECK_FAILED cycle=%0d %s", cycles, label);
  endtask

  function automatic logic [PORT_DATA_WIDTH-1:0] pattern(input integer p, input integer row);
    logic [PORT_DATA_WIDTH-1:0] value;
    // Every nibble can be reconstructed without a numeric/quantization policy.
    for (integer n = 0; n < PORT_DATA_WIDTH/4; n++)
      value[n*4 +: 4] = 4'((p*3 + row*5 + n + 7*(n/16)) % 16);
    return value;
  endfunction

  task automatic idle_inputs;
    ena_i = '0; enb_i = 0; clear_commit_i = 0;
    for (integer p = 0; p < PORT_COUNT; p++) wea_i[p] = '0;
  endtask
  task automatic cycle;
    @(posedge aclk); #0.5; @(negedge aclk);
  endtask
  task automatic drain;
    idle_inputs(); repeat(READ_LATENCY+2) cycle();
  endtask
  task automatic row_write(input integer row);
    ena_i = '1;
    for (integer p = 0; p < PORT_COUNT; p++) begin
      addra_i[p] = ADDR_WIDTH'(row); dina_i[p] = pattern(p,row); wea_i[p] = '1;
    end
    cycle(); idle_inputs();
  endtask
  task automatic row_read(input integer row);
    enb_i = 1; addrb_i = ADDR_WIDTH'(row); cycle(); enb_i = 0;
  endtask
  task automatic clear_epoch;
    idle_inputs(); clear_commit_i = 1; cycle(); clear_commit_i = 0;
    check(commitb_o == 0, "clear publishes empty prefix");
  endtask

  // This model checks every edge, including bubbles and in-flight enable drain.
  always @(posedge aclk) begin : scoreboard
    integer minimum_prefix;
    logic [OUT_WIDTH-1:0] sampled_read;
    cycles++;
    if (!aresetn) begin
      expected_output = '0;
      for (integer q = 0; q < READ_LATENCY; q++) read_pending[q] = 0;
      for (integer p = 0; p < PORT_COUNT; p++) reference_prefix[p] = 0;
    end else begin
      for (integer q = READ_LATENCY-1; q > 0; q--) begin
        read_queue[q] = read_queue[q-1]; read_pending[q] = read_pending[q-1];
      end
      read_pending[0] = enb_i && (64'(addrb_i) < 64'(DEPTH));
      sampled_read = '0;
      if (read_pending[0]) begin
        for (integer p = 0; p < PORT_COUNT; p++)
          for (integer b = 0; b < BYTE_COUNT; b++)
            sampled_read[p*PORT_DATA_WIDTH+b*8 +: 8] = reference_bytes[p][int'(addrb_i)][b];
      end
      read_queue[0] = sampled_read;
      if (read_pending[READ_LATENCY-1]) begin
        expected_output = read_queue[READ_LATENCY-1]; read_checks++;
      end
      for (integer p = 0; p < PORT_COUNT; p++) begin
        if (clear_commit_i) reference_prefix[p] = 0;
        if (!clear_commit_i && ena_i[p] && (64'(addra_i[p]) < 64'(DEPTH))) begin
          for (integer b = 0; b < BYTE_COUNT; b++)
            if (wea_i[p][b]) reference_bytes[p][int'(addra_i[p])][b] = dina_i[p][b*8 +: 8];
          accepted_writes++;
          if ((&wea_i[p]) && (int'(addra_i[p]) == reference_prefix[p])) reference_prefix[p]++;
        end
      end
    end
    minimum_prefix = reference_prefix[0];
    for (integer p = 1; p < PORT_COUNT; p++)
      if (reference_prefix[p] < minimum_prefix) minimum_prefix = reference_prefix[p];
    #0.2;
    check(doutb_o === expected_output, $sformatf("read data/latency/hold expected=%h actual=%h", expected_output,doutb_o));
    check(commitb_o === (ADDR_WIDTH+1)'(minimum_prefix), "minimum exclusive prefix");
    check(rd_address_error_o === (aresetn && enb_i && (64'(addrb_i) >= 64'(DEPTH))), "read error qualification");
    for (integer p = 0; p < PORT_COUNT; p++)
      check(wr_address_error_o[p] === (aresetn && ena_i[p] && (64'(addra_i[p]) >= 64'(DEPTH))), "write error qualification");
  end

  initial begin : stimulus
    logic [OUT_WIDTH-1:0] held_output;
    for (integer p = 0; p < PORT_COUNT; p++) begin
      addra_i[p] = '0; dina_i[p] = '0; wea_i[p] = '0;
      for (integer row = 0; row < DEPTH; row++)
        for (integer b = 0; b < BYTE_COUNT; b++) reference_bytes[p][row][b] = 0;
    end
    repeat(3) cycle(); aresetn = 1;
    // First and last legal row, fully occupied native address space, nibble order.
    for (integer row = 0; row < DEPTH; row++) row_write(row);
    check(commitb_o == (ADDR_WIDTH+1)'(DEPTH), "last row publishes DEPTH without native-address wrap");
    for (integer row = 0; row < DEPTH; row++) row_read(row); // II=1
    drain();
    held_output = doutb_o;
    repeat(5) cycle(); check(doutb_o === held_output, "disabled holds after drain");

    // Independent same-edge write addresses, without inter-stripe arbitration.
    ena_i = '1;
    for (integer p = 0; p < PORT_COUNT; p++) begin
      addra_i[p] = ADDR_WIDTH'(p % DEPTH); dina_i[p] = ~pattern(p,p); wea_i[p] = '1;
    end
    cycle(); idle_inputs();
    for (integer p = 0; p < PORT_COUNT; p++) row_read(p % DEPTH);
    drain(); check(commitb_o == (ADDR_WIDTH+1)'(DEPTH), "older rewrites cannot reduce or overstate prefix");

    // Partial byte enables, followed by a same-address read_first collision.
    ena_i = '1;
    for (integer p = 0; p < PORT_COUNT; p++) begin
      addra_i[p] = 0; dina_i[p] = '1;
      for (integer b = 0; b < BYTE_COUNT; b++) wea_i[p][b] = (b % 2 == 0);
    end
    cycle(); idle_inputs(); row_read(0); drain();
    ena_i = '1; enb_i = 1; addrb_i = 0;
    for (integer p = 0; p < PORT_COUNT; p++) begin addra_i[p] = 0; dina_i[p] = pattern(p,7); wea_i[p] = '1; end
    cycle(); idle_inputs(); drain(); row_read(0); drain();

    // Unequal producer progress: a row is publishable only when every stripe has it.
    clear_epoch();
    for (integer p = 0; p < PORT_COUNT; p++) begin
      ena_i = '0; ena_i[p] = 1; addra_i[p] = 0; dina_i[p] = pattern(p,0); wea_i[p] = '1;
      cycle(); idle_inputs();
      check(commitb_o == ((p == PORT_COUNT-1) ? (ADDR_WIDTH+1)'(1) : (ADDR_WIDTH+1)'(0)), "unequal producers exact minimum");
    end
    // Skipped row updates memory but cannot publish the gap. Partial prefix write also cannot publish.
    row_write(2); check(commitb_o == 1, "gap does not advance commit");
    ena_i = '1;
    for (integer p = 0; p < PORT_COUNT; p++) begin addra_i[p] = 1; dina_i[p] = '0; wea_i[p] = '0; end
    cycle(); idle_inputs(); check(commitb_o == 1, "zero strobe cannot advance commit");
    row_read(1); drain();
    ena_i = '1;
    for (integer p = 0; p < PORT_COUNT; p++) begin addra_i[p] = 1; dina_i[p] = pattern(p,1); wea_i[p] = 1; end
    cycle(); idle_inputs(); check(commitb_o == 1, "partial strobe cannot advance commit");
    row_write(1); check(commitb_o == 2, "hole filled but skipped row still requires replay");
    row_write(0); check(commitb_o == 2, "older rewrite does not advance");
    row_write(2); check(commitb_o == 3, "in-order replay publishes skipped row");
    row_read(2); drain();

    // Clear suppresses a simultaneous write, retains memory, and does not cancel reads.
    ena_i = '1; enb_i = 1; addrb_i = 2; clear_commit_i = 1;
    for (integer p = 0; p < PORT_COUNT; p++) begin addra_i[p] = 2; dina_i[p] = '0; wea_i[p] = '1; end
    cycle(); idle_inputs(); drain(); row_read(2); drain(); check(commitb_o == 0, "clear priority");

    // Reset while a read is pending and writes are asserted: no memory erasure/write.
    row_read(1); aresetn = 0; ena_i = '1;
    for (integer p = 0; p < PORT_COUNT; p++) begin addra_i[p] = 2; dina_i[p] = '0; wea_i[p] = '1; end
    repeat(READ_LATENCY+2) cycle(); idle_inputs(); aresetn = 1;
    drain(); row_read(2); drain(); check(commitb_o == 0, "reset retains memory and clears metadata");

    // Invalid address checks apply when the bus represents addresses beyond DEPTH.
    if (ADDR_WIDTH > $clog2(DEPTH)) begin
      ena_i = '1; enb_i = 1; addrb_i = ADDR_WIDTH'(DEPTH);
      for (integer p = 0; p < PORT_COUNT; p++) begin addra_i[p] = ADDR_WIDTH'(DEPTH); dina_i[p] = '0; wea_i[p] = '1; end
      cycle(); idle_inputs(); drain();
      // High-bit address has the same narrowed XPM row as zero; must not alias it.
      ena_i = '1; enb_i = 1; addrb_i = (ADDR_WIDTH'(1) << (ADDR_WIDTH-1));
      for (integer p = 0; p < PORT_COUNT; p++) begin
        addra_i[p] = (ADDR_WIDTH'(1) << (ADDR_WIDTH-1)); dina_i[p] = '0; wea_i[p] = '1;
      end
      cycle(); idle_inputs(); drain(); row_read(0); row_read(2); drain();
    end
    check(read_checks > DEPTH+5, "meaningful read comparisons executed");
    $display("COUNTS checks=%0d reads=%0d writes=%0d cycles=%0d",checks,read_checks,accepted_writes,cycles);
    $display("PASS: smollm2 striped bank XPM functional verification");
    $finish;
  end
  initial begin #100000; $fatal(1,"timeout"); end
endmodule
