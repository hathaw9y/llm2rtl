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
                $fatal(1, "NOR mismatch: a=%b b=%b expected=%b actual=%b", a, b, expected, out);
        end
    endtask

    initial begin
        check(0, 0, 1);
        check(0, 1, 0);
        check(1, 1, 0);
        check(1, 0, 0);
        check(0, 0, 1);
        $display("PASS: NOR truth table and return transition");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
