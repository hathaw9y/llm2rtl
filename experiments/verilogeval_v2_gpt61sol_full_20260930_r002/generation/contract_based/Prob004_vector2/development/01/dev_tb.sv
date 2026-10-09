`timescale 1ns/1ps
module dev_tb;
    logic [31:0] in;
    wire [31:0] out;
    integer checks = 0;
    integer i, b, value;
    logic [31:0] pattern;
    logic [31:0] prng = 32'h13579bdf;
    TopModule dut (.in(in), .out(out));

    task automatic check(input logic [31:0] stimulus);
        logic [31:0] expected;
        integer bit_index;
        begin
            // Independent per-bit oracle: reverse byte positions only.
            for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1)
                expected[(3 - bit_index/8)*8 + bit_index%8] = stimulus[bit_index];
            in = stimulus;
            #1;
            if (out !== expected)
                $fatal(1, "Mismatch input=%h expected=%h actual=%h", stimulus, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check(32'h00000000);
        check(32'hffffffff);
        check(32'h01234567);
        check(32'h89abcdef);
        check(32'hff00aa55);
        check(32'h55aa00ff);
        for (i = 0; i < 32; i = i + 1) begin
            check(32'h00000001 << i);
            check(~(32'h00000001 << i));
        end
        for (b = 0; b < 4; b = b + 1)
            for (value = 0; value < 256; value = value + 1) begin
                pattern = 32'h00000000;
                pattern[b*8 +: 8] = value[7:0];
                check(pattern);
            end
        for (i = 0; i < 1000; i = i + 1) begin
            prng = prng ^ (prng << 13);
            prng = prng ^ (prng >> 17);
            prng = prng ^ (prng << 5);
            check(prng);
        end
        check(32'hxxxxxxxx);
        check(32'hzzzzzzzz);
        check(32'h12xx34zz);
        $display("PASS byte reversal: %0d checks", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
