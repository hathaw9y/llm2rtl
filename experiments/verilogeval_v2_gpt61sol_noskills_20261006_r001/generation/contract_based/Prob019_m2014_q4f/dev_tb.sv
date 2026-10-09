`timescale 1ns/1ps
module dev_tb;
    reg in1, in2;
    wire out;
    integer checks = 0;
    TopModule dut(.in1(in1), .in2(in2), .out(out));

    task check;
        input a, b, expected;
        begin
            in1 = a;
            in2 = b;
            #1;
            if (out !== expected)
                $fatal(1, "in1=%b in2=%b expected=%b got=%b", a, b, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Explicit original AND-with-inverted-second-input truth table.
        check(0, 0, 0);
        check(0, 1, 0);
        check(1, 0, 1);
        check(1, 1, 0);
        // Exercise each input changing while the other is held constant.
        check(1, 0, 1);
        check(0, 0, 0);
        check(1, 0, 1);
        check(1, 1, 0);
        check(0, 1, 0);
        check(0, 0, 0);
        // Supplemental standard four-state gate truth table.
        check(0, 1'bx, 0);
        check(0, 1'bz, 0);
        check(1, 1'bx, 1'bx);
        check(1, 1'bz, 1'bx);
        check(1'bx, 0, 1'bx);
        check(1'bz, 0, 1'bx);
        check(1'bx, 1, 0);
        check(1'bz, 1, 0);
        check(1'bx, 1'bx, 1'bx);
        check(1'bx, 1'bz, 1'bx);
        check(1'bz, 1'bx, 1'bx);
        check(1'bz, 1'bz, 1'bx);
        $display("PASS: %0d combinational gate checks", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
