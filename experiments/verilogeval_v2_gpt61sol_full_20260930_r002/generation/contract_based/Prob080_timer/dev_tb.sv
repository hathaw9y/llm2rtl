`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [9:0] data = 0;
    wire tc;
    integer remaining;
    integer checks = 0;
    integer duration;
    integer n;
    bit known = 0;
    TopModule dut (.clk(clk), .load(load), .data(data), .tc(tc));
    always #5 clk = ~clk;

    task automatic check_output;
        if (known) begin
            if (tc !== (remaining == 0))
                $fatal(1, "tc mismatch at %0t remaining=%0d tc=%b", $time, remaining, tc);
            checks = checks + 1;
        end
    endtask

    task automatic cycle(input bit do_load, input integer value);
        @(negedge clk);
        load = do_load;
        data = value;
        #1;
        check_output(); // Inputs cannot change terminal count between edges.
        @(posedge clk);
        if (do_load) begin
            remaining = value;
            known = 1;
        end else if (known && remaining > 0)
            remaining = remaining - 1;
        #1;
        check_output();
    endtask

    initial begin
        // Startup is unspecified; no expected constant is imposed before loading.
        cycle(1, 0);
        repeat (4) cycle(0, 1023);
        cycle(1, 1);
        cycle(0, 17);
        repeat (3) cycle(0, 99);
        cycle(1, 1023);
        repeat (1023) cycle(0, 1023);
        repeat (3) cycle(0, 0);
        cycle(1, 50);
        repeat (7) cycle(0, 0);
        cycle(1, 2);
        cycle(1, 7);
        cycle(1, 0);
        cycle(1, 3);
        repeat (4) cycle(0, 0);
        // Exercise all legal load values and their precise timeout edge.
        for (duration = 0; duration <= 1023; duration = duration + 1) begin
            cycle(1, duration);
            for (n = 0; n < duration; n = n + 1)
                cycle(0, (duration + n) % 1024);
            cycle(0, 1023);
        end
        $display("PASS timer checks=%0d", checks);
        $finish;
    end
    initial begin
        #6000000;
        $fatal(1, "timeout");
    end
endmodule
