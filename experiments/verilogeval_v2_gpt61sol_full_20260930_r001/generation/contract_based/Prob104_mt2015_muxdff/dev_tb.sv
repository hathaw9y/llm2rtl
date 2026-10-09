`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic L = 0;
    logic q_in = 0;
    logic r_in = 0;
    wire Q;
    logic expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .L(L), .q_in(q_in), .r_in(r_in), .Q(Q));

    task automatic check(input logic value);
        if (Q !== value)
            $fatal(1, "Mismatch: Q=%b expected=%b", Q, value);
        checks = checks + 1;
    endtask

    task automatic tick;
        #2;
        expected = L ? r_in : q_in;
        clk = 1;
        #1;
        check(expected);
        clk = 0;
        #1;
        check(expected);
    endtask

    initial begin
        // Establish known state without assuming power-up initialization.
        L = 1;
        r_in = 0;
        tick();
        for (integer prior = 0; prior < 2; prior = prior + 1) begin
            for (integer pattern = 0; pattern < 8; pattern = pattern + 1) begin
                L = 1;
                r_in = (prior != 0);
                tick();
                L = pattern[2];
                q_in = pattern[1];
                r_in = pattern[0];
                #1;
                check(expected);
                tick();
                // Mutate every mux input while clock remains low.
                L = ~L;
                q_in = ~q_in;
                r_in = ~r_in;
                #1;
                check(expected);
                tick();
            end
        end
        $display("PASS: %0d checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Simulation timeout");
    end
endmodule
