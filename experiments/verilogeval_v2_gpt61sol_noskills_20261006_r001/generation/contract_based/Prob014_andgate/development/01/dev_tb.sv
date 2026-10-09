`timescale 1ns/1ps
module dev_tb;
    reg a, b;
    wire out;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .out(out));

    task automatic check(input reg av, input reg bv, input reg expected);
        begin
            a = av;
            b = bv;
            #1;
            if (out !== expected)
                $fatal(1, "a=%b b=%b expected=%b observed=%b", a, b, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check(0, 0, 0);
        check(0, 1, 0);
        check(1, 0, 0);
        check(1, 1, 1);
        check(0, 1, 0);
        check(1, 1, 1);
        check(1, 0, 0);
        check(0, 0, 0);
        // Supplemental standard Verilog four-state AND truth table.
        check(0, 1'bx, 0);
        check(0, 1'bz, 0);
        check(1, 1'bx, 1'bx);
        check(1, 1'bz, 1'bx);
        check(1'bx, 0, 0);
        check(1'bz, 0, 0);
        check(1'bx, 1, 1'bx);
        check(1'bz, 1, 1'bx);
        check(1'bx, 1'bx, 1'bx);
        check(1'bx, 1'bz, 1'bx);
        check(1'bz, 1'bx, 1'bx);
        check(1'bz, 1'bz, 1'bx);
        check(1, 1, 1);
        check(0, 0, 0);
        $display("PASS: %0d AND gate checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
