`timescale 1ns/1ps
module dev_tb;
    logic [7:0] in;
    wire [31:0] out;
    integer value;
    integer signed expected;
    TopModule dut (.in(in), .out(out));
    initial begin
        for (value = 0; value < 256; value = value + 1) begin
            in = value[7:0];
            expected = (value < 128) ? value : value - 256;
            #1;
            if (out !== expected) begin
                $fatal(1, "FAIL input=%h actual=%h expected=%h", in, out, expected);
            end
        end
        $display("PASS: all 256 inputs sign-extended correctly");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
