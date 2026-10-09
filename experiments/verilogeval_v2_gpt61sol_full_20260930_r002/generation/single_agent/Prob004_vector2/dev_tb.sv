`timescale 1ns/1ps
module dev_tb;
    logic [31:0] in;
    wire [31:0] out;
    integer checks = 0;
    TopModule dut (.in(in), .out(out));

    task automatic check(input logic [31:0] value);
        logic [31:0] expected;
        integer bit_index;
        begin
            // Map each input bit to the same position within the opposite byte.
            for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1)
                expected[(3 - bit_index / 8) * 8 + bit_index % 8] = value[bit_index];
            in = value;
            #1;
            if (out !== expected)
                $fatal(1, "Byte reversal mismatch: in=%h expected=%h out=%h", in, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check(32'h00000000);
        check(32'hffffffff);
        check(32'h01234567);
        check(32'h89abcdef);
        check(32'h000000ff);
        check(32'hff000000);
        check(32'h55aa00ff);
        for (integer i = 0; i < 32; i = i + 1) begin
            check(32'h00000001 << i);
            check(~(32'h00000001 << i));
        end
        for (integer byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
            for (integer value = 0; value < 256; value = value + 1)
                check(32'(value) << (8 * byte_index));
        check(32'hxx12zz34);
        check(32'hzzzzxxxx);
        for (integer i = 0; i < 1000; i = i + 1)
            check($urandom);
        $display("PASS byte reversal: %0d checks", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
