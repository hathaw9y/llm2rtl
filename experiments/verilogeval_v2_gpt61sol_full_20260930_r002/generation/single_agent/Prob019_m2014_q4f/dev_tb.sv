`timescale 1ns/1ps
module dev_tb;
    logic in1, in2;
    wire out;
    TopModule dut (.in1(in1), .in2(in2), .out(out));

    task automatic check(input logic a, input logic b, input logic expected);
        in1 = a;
        in2 = b;
        #1;
        if (out !== expected)
            $fatal(1, "in1=%b in2=%b expected=%b actual=%b", a, b, expected, out);
    endtask

    initial begin
        check(1'b0, 1'b0, 1'b0);
        check(1'b0, 1'b1, 1'b0);
        check(1'b1, 1'b0, 1'b1);
        check(1'b1, 1'b1, 1'b0);
        check(1'b1, 1'b0, 1'b1);
        check(1'b0, 1'b0, 1'b0);
        $display("PASS all truth-table and transition checks");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
