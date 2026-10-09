`timescale 1ns/1ps
module dev_tb;
    reg d;
    reg ena;
    wire q;
    reg held;
    integer i;
    TopModule dut (.d(d), .ena(ena), .q(q));

    task check_q(input reg expected);
        begin
            if (q !== expected)
                $fatal(1, "Latch mismatch: ena=%b d=%b q=%b expected=%b", ena, d, q, expected);
        end
    endtask

    initial begin
        d = 0;
        ena = 0;
        #1;
        // With no reset or enabled write, the simulated latch is uninitialized.
        check_q(1'bx);
        d = 1;
        #1;
        check_q(1'bx);

        // Enable without changing d: the current input must be captured.
        ena = 1;
        #1;
        check_q(1);
        d = 0;
        #1;
        check_q(0);
        d = 1;
        #1;
        check_q(1);
        ena = 0;
        #1;
        check_q(1);
        d = 0;
        #1;
        check_q(1);

        // Exercise both stored values, open-latch transitions and closed holds.
        for (i = 0; i < 16; i = i + 1) begin
            ena = 1;
            d = i % 2;
            #1;
            check_q(d);
            d = ~d;
            #1;
            check_q(d);
            held = d;
            ena = 0;
            #1;
            check_q(held);
            d = ~held;
            #1;
            check_q(held);
            d = held;
            #1;
            check_q(held);
        end
        $display("PASS D latch transparency and retention checks");
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Testbench timeout");
    end
endmodule
