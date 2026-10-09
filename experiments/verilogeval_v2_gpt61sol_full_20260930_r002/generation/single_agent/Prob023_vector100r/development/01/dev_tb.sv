`timescale 1ns/1ps
module dev_tb;
    logic [99:0] in;
    wire [99:0] out;
    integer checks = 0;
    integer i;
    integer j;
    logic [99:0] pattern;
    TopModule dut (.in(in), .out(out));

    // Build the reversed vector by consuming input LSB first and
    // appending each consumed bit at the expected vector's LSB.
    task automatic check_vector(input logic [99:0] value);
        logic [99:0] remaining;
        logic [99:0] expected;
        integer k;
        begin
            remaining = value;
            expected = '0;
            for (k = 0; k < 100; k = k + 1) begin
                expected = {expected[98:0], remaining[0]};
                remaining = remaining >> 1;
            end
            in = value;
            #1;
            if (out !== expected)
                $fatal(1, "reverse mismatch: in=%h expected=%h actual=%h", value, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_vector('0);
        check_vector('1);
        for (i = 0; i < 100; i = i + 1) begin
            pattern = '0;
            pattern[i] = 1'b1;
            check_vector(pattern);
            check_vector(~pattern);
        end
        for (i = 0; i < 100; i = i + 1)
            pattern[i] = (i % 2 == 0);
        check_vector(pattern);
        check_vector(~pattern);
        for (i = 0; i < 200; i = i + 1) begin
            for (j = 0; j < 100; j = j + 1)
                pattern[j] = $urandom_range(0, 1);
            check_vector(pattern);
        end
        check_vector('x);
        check_vector('z);
        pattern = '0;
        pattern[0] = 1'bx;
        pattern[99] = 1'bz;
        pattern[49] = 1'bx;
        pattern[50] = 1'bz;
        check_vector(pattern);
        $display("PASS bit reversal: %0d vectors", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "timeout");
    end
endmodule
