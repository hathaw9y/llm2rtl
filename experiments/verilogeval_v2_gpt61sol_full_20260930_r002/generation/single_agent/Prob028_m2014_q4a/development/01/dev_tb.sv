`timescale 1ns/1ps
module dev_tb;
    logic d;
    logic ena;
    wire q;
    integer checks = 0;
    TopModule dut (.d(d), .ena(ena), .q(q));

    task automatic check(input logic expected);
        begin
            checks = checks + 1;
            if (q !== expected)
                $fatal(1, "check %0d: d=%b ena=%b expected=%b q=%b", checks, d, ena, expected, q);
        end
    endtask

    initial begin
        d = 1'b0;
        ena = 1'b0;
        // No reset or initialization: closed latch has no stored value yet.
        #1; check(1'bx);
        d = 1'b1;
        #1; check(1'bx);
        ena = 1'b1;
        #1; check(1'b1);
        // Data must propagate without another enable edge.
        d = 1'b0;
        #1; check(1'b0);
        d = 1'b1;
        #1; check(1'b1);
        ena = 1'b0;
        #1; check(1'b1);
        d = 1'b0;
        #1; check(1'b1);
        d = 1'b1;
        #1; check(1'b1);
        d = 1'b0;
        #1; check(1'b1);
        ena = 1'b1;
        #1; check(1'b0);
        ena = 1'b0;
        #1; check(1'b0);
        d = 1'b1;
        #1; check(1'b0);
        repeat (8) begin
            ena = 1'b1;
            #1; check(1'b1);
            d = 1'b0;
            #1; check(1'b0);
            ena = 1'b0;
            #1; check(1'b0);
            d = 1'b1;
            #1; check(1'b0);
        end
        $display("PASS: D latch verified (%0d checks)", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "timeout");
    end
endmodule
