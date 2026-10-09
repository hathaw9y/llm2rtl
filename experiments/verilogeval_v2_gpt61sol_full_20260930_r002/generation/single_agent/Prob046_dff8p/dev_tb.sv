`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic reset = 1'b0;
    logic [7:0] d = 8'h00;
    wire [7:0] q;
    logic [7:0] expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .d(d), .q(q));

    task automatic check_q(input logic [7:0] value);
        if (q !== value)
            $fatal(1, "q mismatch at %0t: got %h expected %h", $time, q, value);
        checks = checks + 1;
    endtask

    // Drive away from clock edges; check hold on rising edges and capture
    // after falling-edge nonblocking assignments have settled.
    task automatic cycle(input logic rst, input logic [7:0] data_value);
        reset = rst;
        d = data_value;
        #2;
        check_q(expected);
        clk = 1'b1;
        #1;
        check_q(expected);
        #2;
        clk = 1'b0;
        if (rst) expected = 8'h34;
        else expected = data_value;
        #1;
        check_q(expected);
    endtask

    initial begin
        // No power-up value is required, so establish state with a reset edge.
        #2;
        reset = 1'b1;
        clk = 1'b1;
        #2;
        clk = 1'b0;
        expected = 8'h34;
        #1;
        check_q(expected);
        cycle(1'b1, 8'hff);
        cycle(1'b0, 8'h00);
        cycle(1'b0, 8'hff);
        cycle(1'b0, 8'haa);
        cycle(1'b0, 8'h55);
        // Reset assertion and deassertion without a falling edge must hold q.
        reset = 1'b1;
        d = 8'h12;
        #2;
        check_q(expected);
        reset = 1'b0;
        #2;
        check_q(expected);
        for (integer i = 0; i < 256; i = i + 1)
            cycle(1'b0, 8'(i));
        cycle(1'b1, 8'h00);
        cycle(1'b1, 8'hff);
        cycle(1'b0, 8'h81);
        $display("PASS: %0d synchronous reset, edge and data checks", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "timeout");
    end
endmodule
