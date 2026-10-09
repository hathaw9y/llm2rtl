`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    wire out;
    TopModule dut (.a(a), .b(b), .out(out));

    task automatic check(input logic av, input logic bv, input logic expected);
        begin
            a = av;
            b = bv;
            #1;
            if (out !== expected)
                $fatal(1, "NOR mismatch a=%b b=%b expected=%b actual=%b", a, b, expected, out);
        end
    endtask

    initial begin
        check(1'b0, 1'b0, 1'b1);
        check(1'b0, 1'b1, 1'b0);
        check(1'b1, 1'b0, 1'b0);
        check(1'b1, 1'b1, 1'b0);
        check(1'b0, 1'b0, 1'b1);
        check(1'b1, 1'b0, 1'b0);
        check(1'b0, 1'b0, 1'b1);
        check(1'b0, 1'b1, 1'b0);
        check(1'b0, 1'b0, 1'b1);
        $display("PASS NOR truth table and input transitions");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
