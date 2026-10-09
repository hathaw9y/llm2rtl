`timescale 1ns/1ps
module dev_tb;
    logic [99:0] in;
    wire out_and, out_or, out_xor;
    integer checks = 0;
    logic [99:0] pattern;
    TopModule dut (.in(in), .out_and(out_and), .out_or(out_or), .out_xor(out_xor));

    task automatic check(input logic [99:0] value);
        logic expected_and, expected_or, expected_xor;
        integer ones;
        bit unknown_seen, zero_seen, one_seen;
        begin
            ones = 0;
            unknown_seen = 0;
            zero_seen = 0;
            one_seen = 0;
            for (integer j = 0; j < 100; j = j + 1) begin
                case (value[j])
                    1'b0: zero_seen = 1;
                    1'b1: begin one_seen = 1; ones = ones + 1; end
                    default: unknown_seen = 1;
                endcase
            end
            if (zero_seen) expected_and = 0;
            else if (unknown_seen) expected_and = 1'bx;
            else expected_and = 1;
            if (one_seen) expected_or = 1;
            else if (unknown_seen) expected_or = 1'bx;
            else expected_or = 0;
            if (unknown_seen) expected_xor = 1'bx;
            else expected_xor = (ones % 2) != 0;
            in = value;
            #1;
            if ({out_and, out_or, out_xor} !== {expected_and, expected_or, expected_xor})
                $fatal(1, "Mismatch input=%h actual=%b expected=%b", value,
                       {out_and, out_or, out_xor}, {expected_and, expected_or, expected_xor});
            checks = checks + 1;
        end
    endtask

    initial begin
        check('0);
        check('1);
        for (integer i = 0; i < 100; i = i + 1) begin
            pattern = '0; pattern[i] = 1'b1; check(pattern);
            pattern = '1; pattern[i] = 1'b0; check(pattern);
        end
        // Exercise every population count, including both parity values.
        pattern = '0;
        for (integer i = 0; i < 100; i = i + 1) begin
            pattern[i] = 1'b1; check(pattern);
        end
        for (integer i = 0; i < 200; i = i + 1) begin
            for (integer j = 0; j < 100; j = j + 1)
                pattern[j] = $urandom_range(0, 1);
            check(pattern);
        end
        check('x);
        check('z);
        pattern = '0; pattern[99] = 1'bx; check(pattern);
        pattern = '1; pattern[0] = 1'bx; check(pattern);
        pattern = '0; pattern[0] = 1'bz; pattern[99] = 1'b1; check(pattern);
        pattern = '1; pattern[99] = 1'bz; pattern[0] = 1'b0; check(pattern);
        $display("PASS %0d combinational checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
