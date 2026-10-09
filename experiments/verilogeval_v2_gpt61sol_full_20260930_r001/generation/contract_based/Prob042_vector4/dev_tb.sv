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
                $fatal(1, "FAIL input=%h expected=%h actual=%h", in, expected, out);
            end
        end
        $display("PASS: all 256 input patterns preserve signed value");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
