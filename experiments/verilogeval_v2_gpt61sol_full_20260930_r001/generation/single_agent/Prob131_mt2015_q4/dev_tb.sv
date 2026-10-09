`timescale 1ns/1ps
module dev_tb;
    logic x, y;
    wire z;
    logic [3:0] expected;
    integer i;
    top_module dut (.x(x), .y(y), .z(z));
    initial begin
        expected = 4'b0101;
        for (i = 0; i < 4; i = i + 1) begin
            {x, y} = i[1:0];
            #1;
            if (z !== expected[i])
                $fatal(1, "FAIL x=%b y=%b z=%b expected=%b", x, y, z, expected[i]);
        end
        $display("PASS: all four binary input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
