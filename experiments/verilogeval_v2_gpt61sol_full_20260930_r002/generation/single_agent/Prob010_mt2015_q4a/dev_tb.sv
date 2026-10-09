`timescale 1ns/1ps
module dev_tb;
    logic x, y;
    wire z;
    TopModule dut (.x(x), .y(y), .z(z));

    task automatic check(input logic a, input logic b, input logic expected);
        x = a;
        y = b;
        #1;
        if (z !== expected)
            $fatal(1, "x=%b y=%b expected=%b got=%b", x, y, expected, z);
    endtask

    initial begin
        // Exhaustive binary truth table, repeated in reverse transition order.
        check(1'b0, 1'b0, 1'b0);
        check(1'b0, 1'b1, 1'b0);
        check(1'b1, 1'b0, 1'b1);
        check(1'b1, 1'b1, 1'b0);
        check(1'b1, 1'b0, 1'b1);
        check(1'b0, 1'b1, 1'b0);
        check(1'b0, 1'b0, 1'b0);
        $display("PASS exhaustive Boolean truth table and transitions");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
