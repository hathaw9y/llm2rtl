`timescale 1ns/1ps
module dev_tb;
    logic in1, in2;
    wire out;
    integer checks = 0;
    TopModule dut (.in1(in1), .in2(in2), .out(out));

    task automatic check_gate(input logic a, input logic b, input logic expected);
        begin
            in1 = a;
            in2 = b;
            #1;
            if (out !== expected)
                $fatal(1, "Mismatch in1=%b in2=%b expected=%b actual=%b", a, b, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Explicit original-circuit truth table, then input-by-input transitions.
        check_gate(1'b0, 1'b0, 1'b0);
        check_gate(1'b0, 1'b1, 1'b0);
        check_gate(1'b1, 1'b0, 1'b1);
        check_gate(1'b1, 1'b1, 1'b0);
        check_gate(1'b0, 1'b1, 1'b0);
        check_gate(1'b0, 1'b0, 1'b0);
        check_gate(1'b1, 1'b0, 1'b1);
        check_gate(1'b1, 1'b1, 1'b0);
        // Supplementary Verilog gate propagation with unknown/high-impedance inputs.
        check_gate(1'b0, 1'bx, 1'b0);
        check_gate(1'b0, 1'bz, 1'b0);
        check_gate(1'b1, 1'bx, 1'bx);
        check_gate(1'b1, 1'bz, 1'bx);
        check_gate(1'bx, 1'b1, 1'b0);
        check_gate(1'bz, 1'b1, 1'b0);
        check_gate(1'bx, 1'b0, 1'bx);
        check_gate(1'bz, 1'b0, 1'bx);
        check_gate(1'b1, 1'b0, 1'b1);
        $display("PASS: %0d gate checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
