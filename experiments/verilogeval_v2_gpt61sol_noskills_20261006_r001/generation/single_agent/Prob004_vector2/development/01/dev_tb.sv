`timescale 1ns/1ps
module dev_tb;
    reg [31:0] in;
    wire [31:0] out;
    integer checks = 0;
    integer i;
    TopModule dut(.in(in), .out(out));

    task automatic check(input reg [31:0] value);
        reg [31:0] expected;
        integer byte_index;
        begin
            for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
                expected[byte_index*8 +: 8] = value[(3-byte_index)*8 +: 8];
            in = value;
            #1;
            if (out !== expected)
                $fatal(1, "Byte reversal mismatch: in=%h expected=%h out=%h", value, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check(32'h00000000);
        check(32'hffffffff);
        check(32'h01234567);
        check(32'h89abcdef);
        check(32'hff000000);
        check(32'h000000ff);
        check(32'h00ff0000);
        check(32'h0000ff00);
        check(32'ha55a00ff);
        for (i = 0; i < 32; i = i + 1) begin
            check(32'h00000001 << i);
            check(~(32'h00000001 << i));
        end
        for (i = 0; i < 256; i = i + 1) begin
            check(i);
            check(i << 8);
            check(i << 16);
            check(i << 24);
        end
        for (i = 0; i < 1000; i = i + 1)
            check($urandom);
        check(32'hxx123456);
        check(32'h12zz3456);
        check(32'h1234xx56);
        check(32'h123456zz);
        $display("PASS: byte reversal verified in %0d cases", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
