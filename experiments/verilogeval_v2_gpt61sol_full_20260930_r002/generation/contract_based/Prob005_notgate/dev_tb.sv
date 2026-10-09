`timescale 1ns/1ps
module dev_tb;
    logic in;
    wire out;
    integer checks = 0;

    TopModule dut (.in(in), .out(out));

    task automatic check_value(input logic stimulus, input logic expected);
        in = stimulus;
        #1;
        if (out !== expected)
            $fatal(1, "NOT mismatch: in=%b expected=%b actual=%b", in, expected, out);
        checks = checks + 1;
    endtask

    initial begin
        check_value(1'b0, 1'b1);
        check_value(1'b1, 1'b0);
        check_value(1'b1, 1'b0);
        check_value(1'b0, 1'b1);
        check_value(1'b0, 1'b1);
        repeat (8) begin
            check_value(1'b1, 1'b0);
            check_value(1'b0, 1'b1);
        end
        // Supplemental standard four-state NOT behavior, unspecified by problem.
        check_value(1'bx, 1'bx);
        check_value(1'bz, 1'bx);
        check_value(1'b0, 1'b1);
        check_value(1'b1, 1'b0);
        $display("PASS NOT gate: %0d checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
