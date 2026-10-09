`timescale 1ns/1ps
module dev_tb;
    logic [99:0] in;
    wire [99:0] out_both, out_any, out_different;
    logic [99:0] pattern;
    integer checks = 0;
    TopModule dut (.in(in), .out_both(out_both), .out_any(out_any),
                   .out_different(out_different));

    task automatic check_vector(input logic [99:0] stimulus);
        logic [99:0] expected_both, expected_any, expected_different;
        integer bit_index;
        begin
            in = stimulus;
            for (bit_index = 0; bit_index < 100; bit_index = bit_index + 1) begin
                if (bit_index == 99)
                    expected_both[bit_index] = 1'b0;
                else
                    expected_both[bit_index] = stimulus[bit_index] & stimulus[bit_index+1];
                if (bit_index == 0)
                    expected_any[bit_index] = 1'b0;
                else
                    expected_any[bit_index] = stimulus[bit_index] | stimulus[bit_index-1];
                if (bit_index == 99)
                    expected_different[bit_index] = stimulus[99] ^ stimulus[0];
                else
                    expected_different[bit_index] = stimulus[bit_index] ^ stimulus[bit_index+1];
            end
            #1;
            if (out_both !== expected_both || out_any !== expected_any ||
                out_different !== expected_different)
                $fatal(1, "Mismatch input=%h both=%h expected=%h any=%h expected=%h different=%h expected=%h",
                       stimulus, out_both, expected_both, out_any, expected_any,
                       out_different, expected_different);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_vector('0);
        check_vector('1);
        check_vector({50{2'b10}});
        check_vector({50{2'b01}});
        for (integer i = 0; i < 100; i = i + 1) begin
            pattern = '0;
            pattern[i] = 1'b1;
            check_vector(pattern);
            check_vector(~pattern);
            pattern[(i+1)%100] = 1'b1;
            check_vector(pattern);
        end
        for (integer i = 0; i < 1000; i = i + 1) begin
            for (integer j = 0; j < 100; j = j + 1)
                pattern[j] = $urandom_range(0, 1);
            check_vector(pattern);
        end
        // Additional four-state checks exercise bitwise gate semantics.
        check_vector('x);
        check_vector('z);
        pattern = '0;
        pattern[0] = 1'bx;
        pattern[99] = 1'bz;
        check_vector(pattern);
        pattern = '1;
        pattern[50] = 1'bx;
        check_vector(pattern);
        $display("PASS: %0d vectors checked", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
