`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d, e;
    wire [24:0] out;
    reg [4:0] values;
    reg [24:0] expected;
    integer pattern, row, column;
    integer checked = 0;
    TopModule dut(.a(a), .b(b), .c(c), .d(d), .e(e), .out(out));

    // Equality truth table independently encodes the original one-bit comparisons.
    function automatic oracle_equal(input reg left_bit, input reg right_bit);
        begin
            case ({left_bit, right_bit})
                2'b00, 2'b11: oracle_equal = 1'b1;
                2'b01, 2'b10: oracle_equal = 1'b0;
                default: oracle_equal = 1'bx;
            endcase
        end
    endfunction

    task automatic check(input reg [4:0] stimulus);
        begin
            {a, b, c, d, e} = stimulus;
            values = stimulus;
            for (row = 0; row < 5; row = row + 1)
                for (column = 0; column < 5; column = column + 1)
                    expected[24 - 5*row - column] =
                        oracle_equal(values[4-row], values[4-column]);
            #1;
            if (out !== expected)
                $fatal(1, "Input %b: expected %b, got %b", stimulus, expected, out);
            checked = checked + 1;
        end
    endtask

    initial begin
        for (pattern = 0; pattern < 32; pattern = pattern + 1)
            check(pattern[4:0]);
        check(5'bx0101);
        check(5'b0x101);
        check(5'b01x01);
        check(5'b010x1);
        check(5'b0101x);
        check(5'bz1010);
        check(5'b1z010);
        check(5'b10z10);
        check(5'b101z0);
        check(5'b1010z);
        check(5'bxxxxx);
        check(5'bzzzzz);
        check(5'b10101);
        $display("PASS: %0d pairwise-comparison input cases", checked);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
