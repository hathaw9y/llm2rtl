`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    logic sum, cout;
    logic [1:0] expected;
    TopModule dut (.a(a), .b(b), .sum(sum), .cout(cout));
    initial begin
        for (int i = 0; i < 4; i++) begin
            {a, b} = 2'(i);
            expected = {1'b0, a} + {1'b0, b};
            #1;
            if ({cout, sum} !== expected)
                $fatal(1, "FAIL a=%b b=%b expected=%b actual=%b", a, b, expected, {cout, sum});
        end
        $display("PASS: all four half-adder input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
