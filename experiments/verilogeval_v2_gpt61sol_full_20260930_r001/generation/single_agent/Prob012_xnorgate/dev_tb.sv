`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    logic out;
    TopModule dut (.a(a), .b(b), .out(out));
    initial begin
        for (int i = 0; i < 4; i++) begin
            {a, b} = 2'(i);
            #1;
            if (out !== (a == b))
                $fatal(1, "FAIL: a=%b b=%b out=%b", a, b, out);
        end
        $display("PASS: all four XNOR truth-table entries");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
