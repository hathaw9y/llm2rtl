`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg load = 0;
    reg [9:0] data = 0;
    wire tc;
    integer remaining;
    integer cycles = 0;
    integer n;
    integer j;
    reg expected_tc;
    TopModule dut (.clk(clk), .load(load), .data(data), .tc(tc));
    always #5 clk = ~clk;

    // The oracle tracks elapsed duration independently using an integer.
    task step(input reg do_load, input integer value);
        begin
            @(negedge clk);
            load = do_load;
            data = value;
            #1;
            if (tc !== expected_tc)
                $fatal(1, "Output changed before rising edge at cycle %0d", cycles);
            @(posedge clk);
            if (do_load) remaining = value;
            else if (remaining > 0) remaining = remaining - 1;
            expected_tc = (remaining == 0);
            #1;
            cycles = cycles + 1;
            if (tc !== expected_tc)
                $fatal(1, "cycle %0d: load=%b data=%0d remaining=%0d tc=%b expected=%b", cycles, do_load, value, remaining, tc, expected_tc);
        end
    endtask

    initial begin
        expected_tc = 1'bx;
        #1;
        if (tc !== 1'bx) $fatal(1, "Counter unexpectedly initialized without a load");
        step(1, 0);
        repeat (4) step(0, 1023);
        step(1, 1);
        step(0, 0);
        repeat (3) step(0, 1);
        step(1, 1023);
        repeat (1023) step(0, 0);
        repeat (4) step(0, 1023);
        step(1, 100);
        repeat (7) step(0, 0);
        step(1, 2);
        step(0, 0);
        step(1, 0);
        step(0, 1023);
        // Exercise every load value, reload while active, and held load.
        for (n = 0; n < 1024; n = n + 1) begin
            step(1, n);
            step(1, n);
            for (j = 0; j < n + 2; j = j + 1) step(0, (n + j) % 1024);
        end
        $display("PASS timer directed and exhaustive duration checks (%0d cycles)", cycles);
        $finish;
    end

    initial begin
        #6000000;
        $fatal(1, "Timeout");
    end
endmodule
