`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg in = 0;
    wire out;
    reg expected;
    integer i;
    TopModule dut (.clk(clk), .in(in), .out(out));

    task check;
        begin
            if (out !== expected)
                $fatal(1, "Mismatch at %0t: in=%b out=%b expected=%b", $time, in, out, expected);
        end
    endtask

    task cycle(input reg value);
        begin
            // Changes at low clock must not update the flip-flop.
            in = value;
            #2; check;
            clk = 1;
            expected = expected ^ value;
            #1; check; // Observe after the nonblocking assignment.
            // Input changes while high must not affect the stored output.
            in = ~value;
            #2; check;
            clk = 0;
            #1; check; // Falling edge must also leave it unchanged.
        end
    endtask

    initial begin
        expected = 1'bx;
        #1; check;
        cycle(0);
        cycle(1);
        cycle(1'bx);
        cycle(1'bz);
        cycle(0);

        // Verification-only state deposits allow checking the truth table
        // without adding initialization or reset behavior to the DUT.
        dut.out = 1'b0;
        expected = 0;
        #1; check;
        cycle(0);
        cycle(1);
        cycle(0);
        cycle(1);
        for (i = 0; i < 16; i = i + 1)
            cycle(1);
        dut.out = 1'b1;
        expected = 1;
        #1; check;
        cycle(0);
        cycle(1);
        cycle(1);
        cycle(0);
        cycle(1'bx);
        cycle(0);
        dut.out = 1'b0;
        expected = 0;
        #1; check;
        cycle(1'bz);
        cycle(1);
        $display("PASS: initial unknown, XOR feedback, positive-edge sampling, and hold behavior");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
