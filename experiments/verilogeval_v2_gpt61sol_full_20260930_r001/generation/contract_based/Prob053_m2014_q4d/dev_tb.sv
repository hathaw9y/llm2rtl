`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic in = 0;
    wire out;
    logic expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .in(in), .out(out));

    task automatic check(input logic value);
        if (out !== value) $fatal(1, "Mismatch: expected %b, got %b", value, out);
        checks = checks + 1;
    endtask

    task automatic cycle(input logic stimulus);
        in = stimulus;
        #2;
        check(expected);
        clk = 1;
        // Independent binary oracle: zero holds, one complements.
        case (stimulus)
            1'b0: expected = expected;
            1'b1: expected = ~expected;
            default: expected = 1'bx;
        endcase
        #1;
        check(expected);
        clk = 0;
        #1;
        check(expected);
    endtask

    initial begin
        #1;
        expected = 1'bx;
        check(expected);
        cycle(0);
        cycle(1);
        for (integer seed = 0; seed < 2; seed = seed + 1) begin
            // Simulation-only state deposit; no initialization added to DUT.
            dut.out = (seed == 1);
            expected = (seed == 1);
            #1;
            check(expected);
            cycle(0);
            cycle(1);
            cycle(1);
            cycle(0);
            for (integer n = 0; n < 32; n = n + 1)
                cycle(((n % 3) == 0) || ((n % 5) == 0));
        end
        cycle(1'bx);
        dut.out = 1'b0;
        expected = 1'b0;
        cycle(1'bz);
        $display("PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Watchdog timeout");
    end
endmodule
