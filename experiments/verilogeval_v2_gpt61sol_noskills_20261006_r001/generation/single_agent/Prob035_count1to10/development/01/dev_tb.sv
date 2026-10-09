`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    wire [3:0] q;
    integer expected;
    integer checks = 0;
    integer i;
    integer target;
    integer step;

    TopModule dut (.clk(clk), .reset(reset), .q(q));

    task check_value(input integer value);
        begin
            if (q !== value[3:0])
                $fatal(1, "q mismatch: expected %0d, got %0d", value, q);
            checks = checks + 1;
        end
    endtask

    task tick(input reg rst);
        begin
            reset = rst;
            #2;
            check_value(expected); // Inputs alone must not change state.
            clk = 1;
            if (rst)
                expected = 1;
            else
                expected = (expected % 10) + 1;
            #1;
            check_value(expected); // Sample after nonblocking assignments.
            clk = 0;
            #1;
            check_value(expected);
        end
    endtask

    initial begin
        // The specification provides no power-up value; establish state by reset.
        reset = 1;
        #2;
        clk = 1;
        #1;
        expected = 1;
        check_value(expected);
        clk = 0;
        #1;
        tick(1);
        tick(1);
        for (i = 0; i < 40; i = i + 1)
            tick(0);

        // Exercise synchronous reset from every legal count, including ten.
        for (target = 1; target <= 10; target = target + 1) begin
            for (step = 1; step < target; step = step + 1)
                tick(0);
            check_value(target);
            reset = 1;
            #1;
            check_value(target);
            tick(1);
            check_value(1);
        end

        // A reset pulse with no rising edge must have no effect.
        tick(0);
        tick(0);
        reset = 1;
        #2;
        check_value(expected);
        reset = 0;
        #2;
        check_value(expected);
        tick(0);
        for (i = 0; i < 30; i = i + 1)
            tick(0);
        $display("PASS: decade counting and synchronous reset (%0d checks)", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
