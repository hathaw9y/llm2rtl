`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg d = 0;
    reg r = 0;
    wire q;
    reg expected;
    integer checks = 0;
    integer i;
    TopModule dut (.clk(clk), .d(d), .r(r), .q(q));

    task check_q(input reg value);
        begin
            if (q !== value)
                $fatal(1, "q mismatch at %0t: expected %b got %b", $time, value, q);
            checks = checks + 1;
        end
    endtask

    // Each cycle independently checks input changes, the rising edge,
    // high-clock changes, and the falling edge.
    task cycle(input reg data_value, input reg reset_value);
        begin
            d = data_value;
            r = reset_value;
            #2;
            check_q(expected);
            clk = 1;
            if (reset_value) expected = 0;
            else expected = data_value;
            #1;
            check_q(expected);
            d = ~data_value;
            r = ~reset_value;
            #2;
            check_q(expected);
            clk = 0;
            #1;
            check_q(expected);
        end
    endtask

    initial begin
        // Establish a defined state through a synchronous reset edge.
        // The specification places no requirement on power-up q.
        r = 1;
        d = 1;
        #2;
        clk = 1;
        expected = 0;
        #1;
        check_q(expected);
        clk = 0;
        #1;
        check_q(expected);

        cycle(1, 0);
        // Reset assertion while clk is low must preserve the stored one
        // until the next rising edge, where reset overrides d=1.
        cycle(1, 1);
        cycle(0, 1);
        cycle(0, 0);
        cycle(1, 0);
        cycle(0, 0);
        for (i = 0; i < 32; i = i + 1)
            cycle((i % 2) != 0, (i % 5) == 0);
        $display("PASS: synchronous reset D flip-flop, %0d checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
