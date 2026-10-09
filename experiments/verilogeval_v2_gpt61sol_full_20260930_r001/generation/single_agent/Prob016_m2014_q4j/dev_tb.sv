`timescale 1ns/1ps
module dev_tb;
    logic [3:0] x, y;
    logic [4:0] sum;
    logic [4:0] expected;
    TopModule dut (.x(x), .y(y), .sum(sum));
    initial begin
        for (int a = 0; a < 16; a++) begin
            for (int b = 0; b < 16; b++) begin
                x = 4'(a);
                y = 4'(b);
                expected = 5'(a + b);
                #1;
                if (sum !== expected)
                    $fatal(1, "FAIL x=%0d y=%0d sum=%0d expected=%0d", x, y, sum, expected);
            end
        end
        $display("PASS: all 256 input combinations");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL: timeout");
    end
endmodule
