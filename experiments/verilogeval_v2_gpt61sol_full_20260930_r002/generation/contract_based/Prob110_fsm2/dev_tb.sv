`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic j = 0;
    logic k = 0;
    wire out;
    bit expected = 0;
    bit initialized = 0;
    integer checks = 0;
    integer s, pair;
    TopModule dut (.clk(clk), .areset(areset), .j(j), .k(k), .out(out));
    always #5 clk = ~clk;

    task automatic check_output;
        if (out !== expected)
            $fatal(1, "Mismatch at %0t: j=%b k=%b reset=%b expected=%b out=%b", $time, j, k, areset, expected, out);
        checks = checks + 1;
    endtask

    // Behavioral oracle uses only the original two-state diagram.
    always @(posedge clk or posedge areset) begin
        if (areset) begin
            expected = 0;
            initialized = 1;
        end else if (initialized) begin
            if (expected == 0) begin
                if (j == 1) expected = 1;
            end else begin
                if (k == 1) expected = 0;
            end
        end
        #1;
        if (initialized) check_output();
    end

    task automatic cycle(input bit next_j, input bit next_k);
        @(negedge clk);
        j = next_j;
        k = next_k;
        #1;
        check_output(); // Input changes must not change a Moore output.
        @(posedge clk);
        #2;
        check_output();
    endtask

    task automatic reset_off_edge;
        @(negedge clk);
        #2;
        areset = 1;
        #2;
        check_output();
        @(negedge clk);
        #2;
        areset = 0;
        #1;
        check_output();
    endtask

    initial begin
        // No output assertion before the first reset: power-up is unspecified.
        #2 areset = 1;
        #2 check_output();
        @(negedge clk);
        #2 areset = 0;
        #1 check_output();

        // Each input combination is checked from both diagram states.
        for (s = 0; s < 2; s = s + 1) begin
            for (pair = 0; pair < 4; pair = pair + 1) begin
                reset_off_edge();
                if (s == 1) cycle(1, 0);
                cycle((pair >> 1) & 1, pair & 1);
            end
        end

        // Simultaneous asserted inputs alternate ON and OFF each cycle.
        repeat (8) cycle(1, 1);
        cycle(1, 0);
        cycle(0, 0);
        cycle(1, 0);
        reset_off_edge(); // Reset from ON between clock edges.

        // Hold reset while both transition inputs are asserted.
        @(negedge clk);
        #2 areset = 1;
        j = 1;
        k = 1;
        repeat (3) begin
            @(posedge clk);
            #2 check_output();
        end
        @(negedge clk);
        #2 areset = 0;
        #1 check_output(); // Release does not itself transition.
        @(posedge clk);
        #2 check_output();
        cycle(0, 0);
        cycle(0, 1);
        $display("PASS: Moore FSM transition, stability, and asynchronous reset checks (%0d comparisons)", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
