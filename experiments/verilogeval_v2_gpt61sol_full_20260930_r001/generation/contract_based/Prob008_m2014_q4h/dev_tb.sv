`timescale 1ns/1ps
module dev_tb;
    logic in;
    wire out;
    integer checks = 0;
    TopModule dut (.in(in), .out(out));

    task automatic check_value(input logic value);
        in = value;
        #1;
        if (out !== value)
            $fatal(1, "FAIL: in=%b out=%b", value, out);
        checks = checks + 1;
    endtask

    initial begin
        check_value(1'b0);
        check_value(1'b1);
        check_value(1'b0);
        check_value(1'b1);
        check_value(1'bx);
        check_value(1'bz);
        check_value(1'b0);
        $display("PASS: %0d identity checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "FAIL: development simulation timeout");
    end
endmodule
