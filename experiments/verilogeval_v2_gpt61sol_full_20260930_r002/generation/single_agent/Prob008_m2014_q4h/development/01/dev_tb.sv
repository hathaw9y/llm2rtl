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
            $fatal(1, "Input %b: expected %b, got %b", in, value, out);
        checks = checks + 1;
    endtask

    initial begin
        // The undriven input initially has its standard four-state X value.
        #1;
        if (out !== 1'bx)
            $fatal(1, "Initial X input must propagate to output");
        checks = checks + 1;
        check_value(1'b0);
        check_value(1'b1);
        check_value(1'b0);
        check_value(1'b1);
        check_value(1'bx);
        check_value(1'bz);
        check_value(1'b0);
        check_value(1'bz);
        check_value(1'b1);
        repeat (16) begin
            check_value(1'b0);
            check_value(1'b1);
        end
        $display("PASS: combinational identity, %0d checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
