`timescale 1ns/1ps
module dev_tb;
    reg in1;
    reg in2;
    wire out;
    TopModule dut (.in1(in1), .in2(in2), .out(out));

    task check;
        input a;
        input b;
        input expected;
        begin
            in1 = a;
            in2 = b;
            #1;
            if (out !== expected)
                $fatal(1, "NOR mismatch: in1=%b in2=%b out=%b expected=%b", a, b, out, expected);
        end
    endtask

    initial begin
        check(0, 0, 1);
        check(0, 1, 0);
        check(1, 0, 0);
        check(1, 1, 0);
        check(0, 0, 1);
        check(1, 1, 0);
        check(1, 0, 0);
        check(0, 0, 1);
        $display("PASS: all NOR truth-table and transition checks succeeded");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
