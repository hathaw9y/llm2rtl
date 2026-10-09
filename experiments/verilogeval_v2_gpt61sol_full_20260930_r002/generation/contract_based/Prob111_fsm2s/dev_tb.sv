`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic j = 0;
    logic k = 0;
    wire out;
    logic expected;
    bit initialized = 0;
    integer checks = 0;
    integer s, pair, n;
    TopModule dut (.clk(clk), .reset(reset), .j(j), .k(k), .out(out));
    always #5 clk = ~clk;

    task automatic compare;
        if (initialized) begin
            checks = checks + 1;
            if (out !== expected)
                $fatal(1, "Mismatch at %0t: reset=%b j=%b k=%b expected=%b out=%b", $time, reset, j, k, expected, out);
        end
    endtask

    // This oracle stores only the expected Moore output and uses the diagram.
    task automatic step(input bit r, input bit ji, input bit ki);
        @(negedge clk);
        reset = r;
        j = ji;
        k = ki;
        #1;
        compare(); // reset and inputs must not change output asynchronously
        @(posedge clk);
        if (r) begin
            expected = 0;
            initialized = 1;
        end else if (initialized) begin
            if (expected == 0) expected = ji;
            else expected = !ki;
        end
        #1;
        compare();
        #2;
        compare(); // output remains stable within this clock cycle
    endtask

    initial begin
        // No check of power-up state: the original problem leaves it unspecified.
        step(1, 1, 1);
        for (s = 0; s < 2; s = s + 1) begin
            for (pair = 0; pair < 4; pair = pair + 1) begin
                step(1, 0, 0);
                if (s == 1) step(0, 1, 0);
                step(0, (pair & 2) != 0, (pair & 1) != 0);
            end
        end
        for (pair = 0; pair < 4; pair = pair + 1) begin
            step(0, 1, 0); // ensures ON regardless of previous state
            step(1, (pair & 2) != 0, (pair & 1) != 0);
            step(0, 0, 0);
        end
        for (n = 0; n < 128; n = n + 1)
            step((n % 17) == 0, ((n * 7 + n / 3) % 2) != 0,
                 ((n * 3 + n / 5) % 2) != 0);
        $display("PASS: Moore FSM checked with %0d comparisons", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
