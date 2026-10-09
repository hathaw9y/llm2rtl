`timescale 1ns/1ps
module dev_tb;
    reg clk = 1'b0;
    reg reset = 1'b0;
    reg [7:0] d = 8'h00;
    wire [7:0] q;
    reg [7:0] expected;
    integer checks = 0;
    integer i;

    TopModule dut (.clk(clk), .reset(reset), .d(d), .q(q));

    task check_q;
        begin
            if (q !== expected)
                $fatal(1, "q mismatch: expected %h got %h at %0t", expected, q, $time);
            checks = checks + 1;
        end
    endtask

    // Inputs settle away from both clock edges. Only a falling edge
    // updates the independent oracle; comparisons follow NBA settlement.
    task cycle(input reg rst_value, input reg [7:0] data_value);
        begin
            reset = rst_value;
            d = data_value;
            #1; check_q();
            clk = 1'b1;
            #1; check_q();
            #1;
            if (reset == 1'b1) expected = 8'h34;
            else expected = d;
            clk = 1'b0;
            #1; check_q();
        end
    endtask

    initial begin
        // No power-on numeric value is imposed by the original problem.
        // Establish the first known state at a falling edge with reset high.
        #2; reset = 1'b1; d = 8'hff;
        #2; clk = 1'b1;
        #2; clk = 1'b0; expected = 8'h34;
        #1; check_q();

        cycle(1'b1, 8'h00);
        cycle(1'b1, 8'hff);
        cycle(1'b0, 8'ha5);
        // Asserting reset between falling edges must preserve a non-reset
        // state until the next falling edge, including at a rising edge.
        cycle(1'b1, 8'h5a);
        cycle(1'b0, 8'h00);
        cycle(1'b0, 8'hff);
        cycle(1'b0, 8'h55);
        cycle(1'b0, 8'haa);

        // A reset pulse entirely between falling edges has no effect.
        #1; reset = 1'b1; d = 8'h19;
        #1; check_q();
        clk = 1'b1;
        #1; check_q();
        reset = 1'b0;
        #1; check_q();
        expected = 8'h19; clk = 1'b0;
        #1; check_q();

        for (i = 0; i < 256; i = i + 1)
            cycle(1'b0, i[7:0]);
        cycle(1'b1, 8'hcb);
        cycle(1'b0, 8'h34);
        $display("PASS: %0d checks of negative-edge capture and synchronous reset", checks);
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Timeout");
    end
endmodule
