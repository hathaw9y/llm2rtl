`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic in = 1'b0;
    wire out;
    logic expected;
    integer seed;
    integer i;
    TopModule dut (.clk(clk), .in(in), .out(out));

    task automatic step(input logic value);
        begin
            in = value;
            #2;
            if (out !== expected) $fatal(1, "Output changed without rising edge");
            clk = 1'b1;
            expected = expected ^ value;
            #1;
            if (out !== expected) $fatal(1, "Incorrect rising-edge update");
            clk = 1'b0;
            #1;
            if (out !== expected) $fatal(1, "Output changed on falling edge");
        end
    endtask

    initial begin
        #1;
        if (out !== 1'bx) $fatal(1, "Unexpected initialization");
        expected = 1'bx;
        step(1'b0);
        step(1'b1);
        for (seed = 0; seed < 2; seed = seed + 1) begin
            // Simulation-only seed to exercise both possible physical states.
            dut.out = (seed == 1);
            expected = (seed == 1);
            step(1'b0);
            step(1'b1);
            step(1'b1);
            step(1'b0);
            for (i = 0; i < 32; i = i + 1)
                step((i % 3) != 0);
        end
        $display("PASS: startup, hold, toggle, and edge behavior");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Testbench timeout");
    end
endmodule
