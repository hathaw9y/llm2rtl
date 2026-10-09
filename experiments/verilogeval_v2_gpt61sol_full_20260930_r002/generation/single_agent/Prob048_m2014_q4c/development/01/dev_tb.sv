`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic d = 0;
    logic r = 0;
    wire q;
    logic expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .d(d), .r(r), .q(q));

    task automatic check(input logic value);
        begin
            checks = checks + 1;
            if (q !== value)
                $fatal(1, "Mismatch at %0t: q=%b expected=%b", $time, q, value);
        end
    endtask

    // Drive inputs while low, then independently check the specified edge behavior.
    task automatic cycle(input logic data_value, input logic reset_value);
        begin
            d = data_value;
            r = reset_value;
            #2;
            check(expected);
            clk = 1;
            expected = reset_value ? 1'b0 : data_value;
            #1;
            check(expected);
            // Changes during the high phase must not affect the stored output.
            d = ~data_value;
            r = ~reset_value;
            #2;
            check(expected);
            clk = 0;
            #1;
            check(expected);
        end
    endtask

    initial begin
        // No initial output value is required; establish known state by reset.
        r = 1;
        d = 1;
        #2;
        clk = 1;
        expected = 0;
        #1;
        check(expected);
        clk = 0;
        #1;
        cycle(1, 0);
        cycle(0, 0);
        cycle(1, 0);
        cycle(1, 1);
        cycle(0, 1);
        cycle(1, 1);
        cycle(1, 0);
        cycle(1, 0);
        cycle(0, 0);
        cycle(0, 0);
        cycle(0, 1);
        cycle(1, 0);
        $display("PASS: synchronous D flip-flop, %0d checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
