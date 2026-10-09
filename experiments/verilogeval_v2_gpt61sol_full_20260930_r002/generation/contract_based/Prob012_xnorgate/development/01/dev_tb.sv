`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    wire out;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .out(out));

    task automatic check_pair(input logic va, input logic vb, input logic expected);
        begin
            a = va;
            b = vb;
            #1;
            if (out !== expected)
                $fatal(1, "XNOR mismatch a=%b b=%b expected=%b actual=%b", a, b, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Explicit XNOR truth table from the original gate specification.
        check_pair(1'b0, 1'b0, 1'b1);
        check_pair(1'b0, 1'b1, 1'b0);
        check_pair(1'b1, 1'b0, 1'b0);
        check_pair(1'b1, 1'b1, 1'b1);
        // Repeated transitions with each input changing independently.
        check_pair(1'b0, 1'b1, 1'b0);
        check_pair(1'b0, 1'b0, 1'b1);
        check_pair(1'b1, 1'b0, 1'b0);
        check_pair(1'b1, 1'b1, 1'b1);
        check_pair(1'b0, 1'b0, 1'b1);
        $display("PASS XNOR truth table and transitions: %0d checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
