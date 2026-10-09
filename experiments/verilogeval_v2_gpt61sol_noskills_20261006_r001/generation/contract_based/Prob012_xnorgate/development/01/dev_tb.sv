`timescale 1ns/1ps
module dev_tb;
    reg a, b;
    wire out;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .out(out));

    task check_pair(input reg av, input reg bv, input reg expected);
        begin
            a = av;
            b = bv;
            #1;
            if (out !== expected)
                $fatal(1, "XNOR mismatch: a=%b b=%b expected=%b out=%b", a, b, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_pair(0, 0, 1);
        check_pair(0, 1, 0);
        check_pair(1, 0, 0);
        check_pair(1, 1, 1);
        check_pair(1, 0, 0);
        check_pair(0, 1, 0);
        check_pair(0, 0, 1);
        check_pair(1, 1, 1);
        $display("PASS XNOR truth table and transitions: %0d checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
