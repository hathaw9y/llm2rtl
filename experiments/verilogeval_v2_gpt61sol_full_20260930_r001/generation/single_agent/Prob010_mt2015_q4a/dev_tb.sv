`timescale 1ns/1ps
module dev_tb;
    logic x, y;
    wire z;
    TopModule dut (.x(x), .y(y), .z(z));
    initial begin
        for (int i = 0; i < 4; i++) begin
            {x, y} = 2'(i);
            #1;
            if (z !== (i == 2))
                $fatal(1, "FAIL x=%b y=%b z=%b", x, y, z);
        end
        $display("PASS: all four binary input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
