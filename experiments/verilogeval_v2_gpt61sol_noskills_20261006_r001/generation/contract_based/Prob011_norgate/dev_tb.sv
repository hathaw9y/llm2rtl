`timescale 1ns/1ps
module dev_tb;
    reg a, b;
    wire out;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .out(out));

    task check;
        input av, bv, expected;
        begin
            a = av;
            b = bv;
            #1;
            if (out !== expected)
                $fatal(1, "NOR mismatch: a=%b b=%b expected=%b actual=%b", a, b, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check(0, 0, 1);
        check(0, 1, 0);
        check(1, 0, 0);
        check(1, 1, 0);
        check(0, 0, 1);
        check(1, 0, 0);
        check(0, 0, 1);
        check(0, 1, 0);
        check(0, 0, 1);
        // Supplemental standard four-state NOR cases.
        check(1'bx, 1, 0);
        check(1, 1'bx, 0);
        check(1'bz, 1, 0);
        check(1, 1'bz, 0);
        check(1'bx, 0, 1'bx);
        check(0, 1'bx, 1'bx);
        check(1'bz, 0, 1'bx);
        check(0, 1'bz, 1'bx);
        check(1'bx, 1'bx, 1'bx);
        check(1'bx, 1'bz, 1'bx);
        check(1'bz, 1'bx, 1'bx);
        check(1'bz, 1'bz, 1'bx);
        check(0, 0, 1);
        $display("PASS NOR gate: %0d checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Testbench timeout");
    end
endmodule
