`timescale 1ns/1ps
module dev_tb;
    reg a, b;
    wire out;
    TopModule dut (.a(a), .b(b), .out(out));

    task check;
        input aa, bb, expected;
        begin
            a = aa;
            b = bb;
            #1;
            if (out !== expected)
                $fatal(1, "XNOR mismatch: a=%b b=%b expected=%b got=%b", a, b, expected, out);
        end
    endtask

    initial begin
        check(1'b0, 1'b0, 1'b1);
        check(1'b0, 1'b1, 1'b0);
        check(1'b1, 1'b1, 1'b1);
        check(1'b1, 1'b0, 1'b0);
        check(1'b0, 1'b0, 1'b1);
        check(1'bx, 1'b0, 1'bx);
        check(1'b1, 1'bx, 1'bx);
        check(1'bz, 1'b1, 1'bx);
        check(1'b0, 1'bz, 1'bx);
        check(1'b1, 1'b1, 1'b1);
        $display("PASS XNOR truth table, input transitions, and unknown propagation");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Test timeout");
    end
endmodule
