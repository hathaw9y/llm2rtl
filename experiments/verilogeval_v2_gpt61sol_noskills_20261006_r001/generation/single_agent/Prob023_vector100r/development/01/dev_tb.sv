`timescale 1ns/1ps
module dev_tb;
    reg [99:0] in;
    wire [99:0] out;
    reg [99:0] pattern;
    integer i, j, trial;
    integer checks = 0;
    TopModule dut (.in(in), .out(out));

    // Build the oracle by shifting input bits from low to high.
    task automatic check(input reg [99:0] value);
        reg [99:0] expected;
        integer k;
        begin
            expected = 100'b0;
            for (k = 0; k < 100; k = k + 1)
                expected = {expected[98:0], value[k]};
            in = value;
            #1;
            if (out !== expected)
                $fatal(1, "Mismatch input=%h expected=%h actual=%h", value, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check({100{1'b0}});
        check({100{1'b1}});
        for (i = 0; i < 100; i = i + 1) begin
            pattern = 100'b0;
            pattern[i] = 1'b1;
            check(pattern);
            check(~pattern);
        end
        check({50{2'b01}});
        check({50{2'b10}});
        for (trial = 0; trial < 200; trial = trial + 1) begin
            for (j = 0; j < 100; j = j + 1)
                pattern[j] = $random;
            check(pattern);
        end
        check({100{1'bx}});
        check({100{1'bz}});
        pattern = 100'b0;
        pattern[0] = 1'bx;
        pattern[99] = 1'bz;
        pattern[49] = 1'b1;
        check(pattern);
        $display("PASS: %0d bit reversal checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
