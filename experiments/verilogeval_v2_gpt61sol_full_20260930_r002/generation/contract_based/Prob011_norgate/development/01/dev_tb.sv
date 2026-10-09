`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    wire out;
    integer checks = 0;

    TopModule dut (.a(a), .b(b), .out(out));

    task automatic check_gate(input logic av, input logic bv, input logic expected);
        a = av;
        b = bv;
        #1;
        if (out !== expected)
            $fatal(1, "NOR mismatch a=%b b=%b expected=%b actual=%b", a, b, expected, out);
        checks = checks + 1;
    endtask

    initial begin
        // Explicit NOR truth table, with repeated transitions on each input.
        check_gate(1'b0, 1'b0, 1'b1);
        check_gate(1'b0, 1'b1, 1'b0);
        check_gate(1'b1, 1'b1, 1'b0);
        check_gate(1'b1, 1'b0, 1'b0);
        check_gate(1'b0, 1'b0, 1'b1);
        check_gate(1'b1, 1'b0, 1'b0);
        check_gate(1'b1, 1'b1, 1'b0);
        check_gate(1'b0, 1'b1, 1'b0);
        check_gate(1'b0, 1'b0, 1'b1);
        // Supplemental standard four-state gate behavior, not specified initialization.
        check_gate(1'b1, 1'bx, 1'b0);
        check_gate(1'bx, 1'b1, 1'b0);
        check_gate(1'b1, 1'bz, 1'b0);
        check_gate(1'bz, 1'b1, 1'b0);
        check_gate(1'b0, 1'bx, 1'bx);
        check_gate(1'bx, 1'b0, 1'bx);
        check_gate(1'b0, 1'bz, 1'bx);
        check_gate(1'bz, 1'b0, 1'bx);
        check_gate(1'bx, 1'bx, 1'bx);
        check_gate(1'bx, 1'bz, 1'bx);
        check_gate(1'bz, 1'bx, 1'bx);
        check_gate(1'bz, 1'bz, 1'bx);
        check_gate(1'b0, 1'b0, 1'b1);
        $display("PASS NOR gate: %0d checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
