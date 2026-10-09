`timescale 1ns/1ps
module dev_tb;
    reg in1, in2;
    wire out;
    TopModule dut (.in1(in1), .in2(in2), .out(out));

    task check(input reg a, input reg b, input reg expected);
        begin
            in1 = a;
            in2 = b;
            #1;
            if (out !== expected)
                $fatal(1, "NOR mismatch: in1=%b in2=%b expected=%b got=%b",
                       a, b, expected, out);
        end
    endtask

    initial begin
        check(0, 0, 1);
        check(0, 1, 0);
        check(1, 0, 0);
        check(1, 1, 0);
        check(0, 0, 1);
        // Four-state gate behavior: a known high input dominates OR.
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
        $display("PASS: NOR truth table and four-state behavior");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
