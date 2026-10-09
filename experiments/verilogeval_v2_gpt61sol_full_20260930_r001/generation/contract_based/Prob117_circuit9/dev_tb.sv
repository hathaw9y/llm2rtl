`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic a = 1;
    wire [2:0] q;
    integer expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .a(a), .q(q));

    task automatic check_q(input integer value);
        if (q !== value[2:0])
            $fatal(1, "q mismatch expected=%0d actual=%0d", value, q);
        checks = checks + 1;
    endtask

    task automatic step(input bit load);
        a = load;
        #4;
        clk = 1;
        expected = load ? 4 : (expected + 1) % 7;
        #1;
        check_q(expected);
        clk = 0;
        #1;
        check_q(expected);
    endtask

    initial begin
        #1;
        if (q !== 3'bxxx) $fatal(1, "Expected uninitialized q");
        expected = 0;
        // Six load edges model the old-a sampling at the coincident 45ns edge.
        repeat (6) step(1);
        repeat (4) step(0);
        repeat (28) step(0);
        // Reload from each legal state reached after counting from 4.
        for (integer offset = 0; offset < 7; offset = offset + 1) begin
            step(1);
            repeat (offset) step(0);
            // An input pulse without a rising edge must not change q.
            a = 1;
            #1;
            check_q(expected);
            a = 0;
            #1;
            check_q(expected);
            step(1);
        end
        repeat (3) step(1);
        $display("PASS: %0d output checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Development test timeout");
    end
endmodule
