`timescale 1ns/1ps
module dev_tb;
    reg a, b;
    wire out;
    TopModule dut (.a(a), .b(b), .out(out));

    task check;
        input av, bv, expected;
        begin
            a = av;
            b = bv;
            #1;
            if (out !== expected)
                $fatal(1, "AND mismatch: a=%b b=%b expected=%b actual=%b", a, b, expected, out);
        end
    endtask

    initial begin
        check(0, 0, 0);
        check(0, 1, 0);
        check(1, 1, 1);
        check(1, 0, 0);
        check(1, 1, 1);
        check(0, 0, 0);
        // Four-state gate behavior: zero dominates unknown inputs.
        check(0, 1'bx, 0);
        check(1'bx, 0, 0);
        check(1, 1'bx, 1'bx);
        check(1'bx, 1, 1'bx);
        check(0, 1'bz, 0);
        check(1'bz, 0, 0);
        check(1, 1'bz, 1'bx);
        check(1'bz, 1, 1'bx);
        check(1, 1, 1);
        $display("PASS: AND truth table, transitions, and four-state checks");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
