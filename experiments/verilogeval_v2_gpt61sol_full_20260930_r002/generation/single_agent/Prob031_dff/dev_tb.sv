`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic d = 1'b0;
    wire q;
    logic expected = 1'bx;
    integer checks = 0;
    TopModule dut (.clk(clk), .d(d), .q(q));

    task automatic check_q;
        begin
            if (q !== expected)
                $fatal(1, "Mismatch at %0t: expected %b got %b", $time, expected, q);
            checks = checks + 1;
        end
    endtask

    task automatic cycle(input logic sample);
        begin
            d = sample;
            #2;
            check_q();
            clk = 1'b1;
            expected = sample;
            #1;
            check_q();
            d = ~sample;
            #1;
            check_q();
            clk = 1'b0;
            #1;
            check_q();
            d = sample;
            #1;
            check_q();
        end
    endtask

    initial begin
        #1;
        check_q();
        d = 1'b1;
        #1;
        check_q();
        cycle(1'b0);
        cycle(1'b1);
        cycle(1'b1);
        cycle(1'b0);
        cycle(1'b0);
        cycle(1'b1);
        cycle(1'bx);
        cycle(1'b0);
        cycle(1'bz);
        cycle(1'b1);
        $display("PASS: %0d D flip-flop checks", checks);
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
