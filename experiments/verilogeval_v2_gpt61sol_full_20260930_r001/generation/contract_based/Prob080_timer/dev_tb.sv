`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [9:0] data = 0;
    wire tc;
    integer remaining;
    integer checks = 0;
    integer n, k;
    logic [31:0] rng = 32'h13579bdf;
    TopModule dut (.clk(clk), .load(load), .data(data), .tc(tc));
    always #5 clk = ~clk;

    task automatic step(input bit do_load, input integer value);
        begin
            @(negedge clk);
            load = do_load;
            data = value;
            #1;
            if (checks != 0 && tc !== (remaining == 0))
                $fatal(1, "Output changed between edges");
            @(posedge clk);
            if (do_load) remaining = value;
            else if (remaining > 0) remaining = remaining - 1;
            #1;
            checks = checks + 1;
            if (tc !== (remaining == 0))
                $fatal(1, "Mismatch check=%0d remaining=%0d tc=%b", checks, remaining, tc);
        end
    endtask

    initial begin
        step(1, 0);
        step(0, 1023);
        step(1, 1);
        step(0, 0);
        step(0, 0);
        step(1, 1023);
        step(0, 0);
        step(1, 4);
        step(1, 2);
        step(0, 999);
        step(1, 0);
        for (n = 0; n < 1024; n = n + 1) begin
            step(1, n);
            for (k = 0; k < n; k = k + 1) step(0, 1023-n);
            step(0, 123);
            step(0, 456);
        end
        for (n = 0; n < 5000; n = n + 1) begin
            rng = {rng[30:0], rng[31]^rng[21]^rng[1]^rng[0]};
            step(rng[4:0] == 5'd0, rng[19:10]);
        end
        $display("PASS: %0d checks; exhaustive durations and mixed reloads", checks);
        $finish;
    end
    initial begin
        #10000000;
        $fatal(1, "Watchdog timeout");
    end
endmodule
