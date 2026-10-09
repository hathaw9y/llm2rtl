`timescale 1ns/1ps
module dev_tb;
    logic [254:0] in;
    wire [7:0] out;
    integer checks = 0;
    integer i, j, k;
    logic [254:0] pattern;
    TopModule dut (.in(in), .out(out));

    task automatic check_vector(input logic [254:0] vector);
        logic [254:0] remaining;
        integer expected;
        begin
            remaining = vector;
            expected = 0;
            while (remaining != 255'd0) begin
                if (remaining[0] == 1'b1)
                    expected = expected + 1;
                remaining = remaining >> 1;
            end
            in = vector;
            #1;
            if (out !== expected[7:0])
                $fatal(1, "count mismatch input=%h expected=%0d actual=%0d", vector, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_vector('0);
        check_vector('1);
        for (i = 0; i < 255; i = i + 1) begin
            pattern = '0;
            pattern[i] = 1'b1;
            check_vector(pattern);
            check_vector(~pattern);
        end
        // Exercise every possible result, growing a contiguous prefix of ones.
        pattern = '0;
        check_vector(pattern);
        for (i = 0; i < 255; i = i + 1) begin
            pattern[i] = 1'b1;
            check_vector(pattern);
        end
        for (i = 0; i < 255; i = i + 1)
            pattern[i] = (i % 2 == 0);
        check_vector(pattern);
        check_vector(~pattern);
        for (j = 0; j < 1000; j = j + 1) begin
            for (k = 0; k < 255; k = k + 1)
                pattern[k] = $urandom_range(0, 1);
            check_vector(pattern);
            check_vector(~pattern);
        end
        check_vector('0);
        check_vector('1);
        check_vector('0);
        $display("PASS population count: %0d vectors checked", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "timeout");
    end
endmodule
