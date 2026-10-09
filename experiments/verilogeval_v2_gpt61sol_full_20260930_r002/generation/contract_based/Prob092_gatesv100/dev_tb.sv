`timescale 1ns/1ps
module dev_tb;
    logic [99:0] in;
    wire [99:0] out_both, out_any, out_different;
    logic [99:0] pattern;
    integer checks = 0;
    integer seed = 923100;
    integer unused_random;
    TopModule dut (.in(in), .out_both(out_both), .out_any(out_any),
                   .out_different(out_different));

    task automatic check_vector(input logic [99:0] value);
        logic [99:0] expected_both, expected_any, expected_different;
        integer bit_index;
        begin
            for (bit_index = 0; bit_index < 100; bit_index = bit_index + 1) begin
                if (bit_index == 99) begin
                    expected_both[bit_index] = 1'b0;
                    expected_different[bit_index] = value[bit_index] ^ value[0];
                end else begin
                    expected_both[bit_index] = value[bit_index] & value[bit_index+1];
                    expected_different[bit_index] = value[bit_index] ^ value[bit_index+1];
                end
                if (bit_index == 0)
                    expected_any[bit_index] = 1'b0;
                else
                    expected_any[bit_index] = value[bit_index] | value[bit_index-1];
            end
            in = value;
            #1;
            if (out_both !== expected_both || out_any !== expected_any ||
                out_different !== expected_different)
                $fatal(1, "Mismatch check=%0d input=%h both=%h expected=%h any=%h expected=%h different=%h expected=%h",
                    checks, value, out_both, expected_both, out_any, expected_any,
                    out_different, expected_different);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_vector('0);
        check_vector('1);
        for (integer i = 0; i < 100; i = i + 1)
            pattern[i] = (i % 2 == 0);
        check_vector(pattern);
        check_vector(~pattern);
        for (integer i = 0; i < 100; i = i + 1) begin
            pattern = '0;
            pattern[i] = 1'b1;
            check_vector(pattern);
            check_vector(~pattern);
            pattern[(i+1)%100] = 1'b1;
            check_vector(pattern);
        end
        unused_random = $random(seed);
        for (integer sample = 0; sample < 1000; sample = sample + 1) begin
            for (integer i = 0; i < 100; i = i + 1)
                pattern[i] = $random & 1;
            check_vector(pattern);
        end
        $display("PASS checked %0d input vectors against original per-bit specification", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
