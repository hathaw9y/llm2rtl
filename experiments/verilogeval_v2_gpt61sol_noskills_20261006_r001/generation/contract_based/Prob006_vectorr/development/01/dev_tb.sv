`timescale 1ns/1ps
module dev_tb;
    reg [7:0] in;
    wire [7:0] out;
    integer value;
    integer bit_index;
    integer checks = 0;
    TopModule dut (.in(in), .out(out));

    task automatic check_reverse(input reg [7:0] stimulus);
        reg [7:0] expected;
        integer i;
        begin
            for (i = 0; i < 8; i = i + 1)
                expected[i] = stimulus[7-i];
            in = stimulus;
            #1;
            if (out !== expected)
                $fatal(1, "Reversal mismatch: in=%b expected=%b out=%b", in, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_reverse(8'h00);
        check_reverse(8'hff);
        check_reverse(8'h01);
        check_reverse(8'h80);
        check_reverse(8'haa);
        check_reverse(8'h55);
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
            check_reverse(8'b00000001 << bit_index);
        for (value = 0; value < 256; value = value + 1)
            check_reverse(value[7:0]);
        check_reverse(8'bxxxxxxxx);
        check_reverse(8'bzzzzzzzz);
        check_reverse(8'b10xz01zx);
        check_reverse(8'bz001x110);
        $display("PASS: %0d bit-reversal checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
