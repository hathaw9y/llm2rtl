`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg load = 0;
    reg [9:0] data = 0;
    wire tc;
    integer remaining;
    integer cycles = 0;
    integer n;
    integer k;
    reg known = 0;

    TopModule dut (.clk(clk), .load(load), .data(data), .tc(tc));

    task check_output;
        begin
            if (known && tc !== (remaining == 0))
                $fatal(1, "cycle %0d: remaining=%0d tc=%b", cycles, remaining, tc);
        end
    endtask

    // Only the duration in whole cycles is modeled; no DUT state is inspected.
    task step(input reg do_load, input integer value);
        begin
            clk = 0;
            load = do_load;
            data = value;
            #2;
            check_output(); // Input changes alone must not alter the count.
            #3;
            clk = 1;
            if (do_load) begin
                remaining = value;
                known = 1;
            end else if (known && remaining > 0) begin
                remaining = remaining - 1;
            end
            cycles = cycles + 1;
            #1;
            check_output(); // Sample after NBA state updates.
            #2;
            clk = 0;
            #2;
            check_output(); // Falling edges do not advance the timer.
        end
    endtask

    initial begin
        #1;
        $display("Initial tc=%b (initial counter value is unspecified)", tc);
        step(1, 0);
        repeat (8) step(0, 1023);
        step(1, 1);
        step(0, 0);
        repeat (4) step(0, 1);
        step(1, 2);
        step(0, 0);
        step(0, 0);
        step(1, 1023);
        repeat (1022) step(0, 0);
        step(0, 0);
        repeat (8) step(0, 1023);

        // Active reload, consecutive loads, and cancellation by loading zero.
        step(1, 900);
        repeat (5) step(0, 0);
        step(1, 2);
        step(0, 0);
        step(1, 3);
        step(1, 1);
        step(1, 0);
        repeat (4) step(0, 10);

        // Exhaust every duration, including all bit-width boundaries.
        for (n = 0; n <= 1023; n = n + 1) begin
            step(1, n);
            for (k = 0; k < n; k = k + 1)
                step(0, (k * 37) % 1024);
            step(0, 1023);
        end
        $display("PASS: all timer checks succeeded (%0d cycles)", cycles);
        $finish;
    end

    initial begin
        #10000000;
        $fatal(1, "Timeout");
    end
endmodule
