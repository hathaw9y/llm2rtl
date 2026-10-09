`timescale 1ns/1ps
module dev_tb;
    logic x, y;
    wire z;
    integer checks = 0;
    TopModule dut (.x(x), .y(y), .z(z));

    task automatic check(input logic xv, input logic yv, input logic expected);
        x = xv;
        y = yv;
        #1;
        if (z !== expected)
            $fatal(1, "x=%b y=%b: expected z=%b, got %b", x, y, expected, z);
        checks = checks + 1;
    endtask

    initial begin
        // Explicit original-equation truth table, exercised in both directions.
        check(1'b0, 1'b0, 1'b0);
        check(1'b0, 1'b1, 1'b0);
        check(1'b1, 1'b0, 1'b1);
        check(1'b1, 1'b1, 1'b0);
        check(1'b1, 1'b0, 1'b1);
        check(1'b0, 1'b1, 1'b0);
        check(1'b0, 1'b0, 1'b0);
        // Supplementary checks of the specified bitwise operators.
        check(1'b0, 1'bx, 1'b0);
        check(1'b0, 1'bz, 1'b0);
        check(1'b1, 1'bx, 1'bx);
        check(1'b1, 1'bz, 1'bx);
        check(1'bx, 1'b0, 1'bx);
        check(1'bx, 1'b1, 1'bx);
        check(1'bz, 1'b0, 1'bx);
        check(1'bz, 1'b1, 1'bx);
        check(1'b1, 1'b0, 1'b1);
        $display("PASS: %0d combinational checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
