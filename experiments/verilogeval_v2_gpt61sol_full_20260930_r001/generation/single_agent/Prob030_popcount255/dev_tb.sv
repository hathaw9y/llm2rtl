`timescale 1ns/1ps
module dev_tb;
    logic [254:0] in;
    wire [7:0] out;
    integer checks = 0;
    integer i, j, trial;
    logic [254:0] pattern;
    TopModule dut (.in(in), .out(out));

    task automatic check(input logic [254:0] value);
        integer expected;
        integer k;
        begin
            expected = 0;
            for (k = 0; k < 255; k = k + 1)
                if (value[k]) expected = expected + 1;
            in = value;
            #1;
            if (out !== expected[7:0])
                $fatal(1, "FAIL: expected %0d got %0d", expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check('0);
        check('1);
        for (i = 0; i < 255; i = i + 1) begin
            pattern = '0;
            pattern[i] = 1'b1;
            check(pattern);
            check(~pattern);
        end
        for (i = 0; i <= 255; i = i + 1) begin
            pattern = '0;
            for (j = 0; j < i; j = j + 1) pattern[j] = 1'b1;
            check(pattern);
        end
        for (trial = 0; trial < 1000; trial = trial + 1) begin
            for (j = 0; j < 255; j = j + 1) pattern[j] = $urandom_range(0, 1);
            check(pattern);
        end
        $display("PASS: %0d population-count checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
