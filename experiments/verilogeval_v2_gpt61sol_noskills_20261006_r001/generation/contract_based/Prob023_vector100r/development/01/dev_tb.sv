`timescale 1ns/1ps
module dev_tb;
    reg [99:0] in;
    wire [99:0] out;
    reg [99:0] pattern;
    integer i, j;
    integer checked = 0;
    TopModule dut (.in(in), .out(out));

    // %b serializes MSB first. Read that text backwards to form the
    // expected MSB-first output, independently of DUT bit assignments.
    task automatic check(input reg [99:0] value);
        string bits;
        reg [99:0] expected;
        integer k;
        begin
            bits = $sformatf("%b", value);
            if (bits.len() != 100) $fatal(1, "Oracle width error");
            expected = 0;
            for (k = 99; k >= 0; k = k - 1) begin
                expected = expected << 1;
                case (bits[k])
                    "0": expected[0] = 1'b0;
                    "1": expected[0] = 1'b1;
                    "x", "X": expected[0] = 1'bx;
                    "z", "Z": expected[0] = 1'bz;
                    default: $fatal(1, "Invalid oracle character");
                endcase
            end
            in = value;
            #1;
            if (out !== expected)
                $fatal(1, "Mismatch case %0d: in=%b expected=%b out=%b", checked, in, expected, out);
            checked = checked + 1;
        end
    endtask

    initial begin
        check({100{1'bx}});
        check(100'b0);
        check({100{1'b1}});
        for (i = 0; i < 100; i = i + 1) begin
            pattern = 100'b1 << i;
            check(pattern);
            check(~pattern);
        end
        check(100'h123456789abcdef0123456789);
        check({50{2'b10}});
        check({50{2'b01}});
        for (i = 0; i < 100; i = i + 1) begin
            pattern = 0;
            pattern[i] = 1'bx;
            check(pattern);
            pattern = {100{1'b1}};
            pattern[i] = 1'bz;
            check(pattern);
        end
        for (i = 0; i < 500; i = i + 1) begin
            for (j = 0; j < 100; j = j + 1)
                pattern[j] = $urandom_range(0, 1);
            check(pattern);
        end
        $display("PASS: %0d bit reversal checks", checked);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
