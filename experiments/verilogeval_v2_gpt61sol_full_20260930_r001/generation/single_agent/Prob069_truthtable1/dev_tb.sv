`timescale 1ns/1ps
module dev_tb;
    logic x3, x2, x1;
    logic f;
    logic [7:0] expected;
    TopModule dut (.x3(x3), .x2(x2), .x1(x1), .f(f));
    initial begin
        expected = 8'b10101100;
        for (int i = 0; i < 8; i++) begin
            {x3, x2, x1} = 3'(i);
            #1;
            if (f !== expected[i])
                $fatal(1, "FAIL: input=%03b expected=%b actual=%b", {x3,x2,x1}, expected[i], f);
        end
        $display("PASS: all 8 truth-table rows");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
