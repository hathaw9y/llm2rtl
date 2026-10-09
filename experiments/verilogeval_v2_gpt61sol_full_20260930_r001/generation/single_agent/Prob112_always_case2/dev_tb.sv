`timescale 1ns/1ps
module dev_tb;
    logic [3:0] in;
    wire [1:0] pos;
    logic [1:0] expected;
    integer value;
    integer bit_index;
    integer found;
    TopModule dut (.in(in), .pos(pos));
    initial begin
        for (value = 0; value < 16; value = value + 1) begin
            in = value[3:0];
            expected = 2'd0;
            found = 0;
            for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1) begin
                if (((value >> bit_index) & 1) && !found) begin
                    expected = bit_index[1:0];
                    found = 1;
                end
            end
            #1;
            if (pos !== expected)
                $fatal(1, "FAIL in=%b expected=%d actual=%d", in, expected, pos);
        end
        $display("PASS: all 16 binary input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
