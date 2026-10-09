`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic slowena = 0;
    wire [3:0] q;
    integer expected;
    integer checks = 0;
    integer i;
    logic initialized = 0;
    logic [3:0] held;
    TopModule dut (.clk(clk), .reset(reset), .slowena(slowena), .q(q));

    task automatic cycle(input logic rst, input logic ena);
        begin
            held = q;
            reset = rst;
            slowena = ena;
            #2;
            if (initialized && q !== held)
                $fatal(1, "Output changed without a rising edge");
            clk = 1;
            if (rst) begin
                expected = 0;
                initialized = 1;
            end else if (initialized && ena)
                expected = (expected + 1) % 10;
            #1;
            if (initialized) begin
                if (q !== expected[3:0])
                    $fatal(1, "check %0d reset=%b enable=%b expected=%0d got=%b", checks, rst, ena, expected, q);
                checks = checks + 1;
            end
            held = q;
            #2;
            clk = 0;
            #1;
            if (q !== held)
                $fatal(1, "Output changed on a falling edge");
        end
    endtask

    initial begin
        // Initial register value is unspecified; establish it with reset.
        cycle(1, 0);
        cycle(1, 1);
        for (i = 0; i < 30; i = i + 1)
            cycle(0, 1);
        // Pause at every count, including 9, before continuing.
        for (i = 0; i < 10; i = i + 1) begin
            cycle(0, 0);
            cycle(0, 0);
            cycle(0, 1);
        end
        for (i = 0; i < 7; i = i + 1)
            cycle(0, 1);
        cycle(1, 0);
        cycle(0, 0);
        cycle(0, 1);
        cycle(1, 1);
        cycle(1, 1);
        for (i = 0; i < 100; i = i + 1)
            cycle((i % 23) == 22, (i % 4) != 1);
        $display("PASS decade counter: %0d checks", checks);
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Timeout");
    end
endmodule
