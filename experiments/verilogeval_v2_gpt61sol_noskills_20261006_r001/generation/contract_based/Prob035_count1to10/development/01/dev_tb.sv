`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    wire [3:0] q;
    integer expected;
    integer steps = 0;
    integer i;
    integer target;
    TopModule dut (.clk(clk), .reset(reset), .q(q));

    task check_value;
        begin
            if (q !== expected[3:0])
                $fatal(1, "step %0d: expected %0d, got %b", steps, expected, q);
        end
    endtask

    task tick;
        begin
            #2;
            clk = 1;
            if (reset)
                expected = 1;
            else
                expected = (expected % 10) + 1;
            steps = steps + 1;
            #1;
            check_value;
            #2;
            clk = 0;
            #1;
            check_value;
        end
    endtask

    initial begin
        // Power-up state is unspecified. Establish it with a rising-edge reset.
        reset = 1;
        tick;
        reset = 0;
        #1;
        check_value;
        for (i = 0; i < 40; i = i + 1)
            tick;

        // A pulse wholly between rising edges must not reset the counter.
        tick;
        reset = 1;
        #1;
        check_value;
        reset = 0;
        #1;
        check_value;
        tick;

        // Apply synchronous reset starting at every value in the legal sequence.
        for (target = 1; target <= 10; target = target + 1) begin
            reset = 1;
            #1;
            check_value;
            tick;
            reset = 0;
            for (i = 1; i < target; i = i + 1)
                tick;
            if (expected != target)
                $fatal(1, "Testbench failed to reach directed target");
            reset = 1;
            #1;
            check_value;
            tick;
            tick;
            reset = 0;
            #1;
            check_value;
            tick;
        end
        $display("PASS: decade sequence, wraparound, and synchronous reset checks (%0d edges)", steps);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
