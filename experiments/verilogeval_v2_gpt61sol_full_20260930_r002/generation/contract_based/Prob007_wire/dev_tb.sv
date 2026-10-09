`timescale 1ns/1ps
module dev_tb;
    logic in;
    wire out;
    logic values [0:3];
    integer checks = 0;
    integer a, b, i;

    TopModule dut (.in(in), .out(out));

    task automatic check_value(input logic expected);
        if (out !== expected)
            $fatal(1, "Wire mismatch: in=%b expected=%b out=%b", in, expected, out);
        checks = checks + 1;
    endtask

    task automatic drive_check(input logic value);
        in = value;
        #1;
        check_value(value);
    endtask

    initial begin
        // The original wire requirement supplies the identity oracle.
        // An uninitialized four-state stimulus starts at X.
        #1;
        check_value(1'bx);
        values[0] = 1'b0;
        values[1] = 1'b1;
        values[2] = 1'bx;
        values[3] = 1'bz;
        for (a = 0; a < 4; a = a + 1) begin
            for (b = 0; b < 4; b = b + 1) begin
                drive_check(values[a]);
                drive_check(values[b]);
            end
        end
        for (i = 0; i < 32; i = i + 1)
            drive_check((i % 2) == 1);
        $display("PASS wire identity: %0d checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
