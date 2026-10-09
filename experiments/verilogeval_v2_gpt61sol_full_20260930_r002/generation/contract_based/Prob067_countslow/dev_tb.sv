`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic slowena = 0;
    wire [3:0] q;
    integer enabled_edges = 0;
    integer expected_value;
    integer checks = 0;
    integer edges = 0;
    bit initialized = 0;
    integer state_index;
    integer cycle_index;
    logic [15:0] stimulus = 16'hbace;

    TopModule dut (.clk(clk), .reset(reset), .slowena(slowena), .q(q));
    always #5 clk = ~clk;

    task automatic compare_output;
        begin
            if (initialized) begin
                expected_value = enabled_edges % 10;
                if (q !== expected_value[3:0])
                    $fatal(1, "Mismatch t=%0t edge=%0d reset=%b slowena=%b expected=%0d actual=%b",
                           $time, edges, reset, slowena, expected_value, q);
                checks = checks + 1;
            end
        end
    endtask

    // Oracle counts accepted enabled edges; it does not mirror the DUT wrap comparator.
    always @(posedge clk) begin
        compare_output();
        edges = edges + 1;
        if (reset) begin
            enabled_edges = 0;
            initialized = 1;
        end else if (initialized && slowena)
            enabled_edges = enabled_edges + 1;
        #1;
        compare_output();
    end
    always @(negedge clk) begin
        #0.1;
        compare_output();
    end

    task automatic step(input bit reset_value, input bit enable_value);
        begin
            @(negedge clk);
            reset = reset_value;
            slowena = enable_value;
            #1;
            compare_output();
            @(posedge clk);
            #2;
            compare_output();
        end
    endtask

    initial begin
        step(1, 0);
        step(1, 1);
        step(0, 0);
        // Reach every legal state and pause there for several clocks.
        for (state_index = 0; state_index < 10; state_index = state_index + 1) begin
            repeat (3) step(0, 0);
            step(0, 1);
        end
        repeat (35) step(0, 1);
        // Reset from every state, both with and without enable asserted.
        for (state_index = 0; state_index < 10; state_index = state_index + 1) begin
            step(1, 0);
            repeat (state_index) step(0, 1);
            step(1, 1);
            step(0, 0);
        end
        // Nonzero state, pulse reset strictly between rising edges.
        repeat (4) step(0, 1);
        @(negedge clk);
        slowena = 0;
        #1 reset = 1;
        #1 compare_output();
        reset = 0;
        #1 compare_output();
        @(posedge clk);
        #2 compare_output();
        // Deterministic mixed resets, pauses, and bursts.
        for (cycle_index = 0; cycle_index < 200; cycle_index = cycle_index + 1) begin
            stimulus = {stimulus[14:0], stimulus[15] ^ stimulus[13] ^ stimulus[12] ^ stimulus[10]};
            step((cycle_index % 37) == 0, stimulus[0]);
        end
        $display("PASS decade counter: %0d comparisons across %0d rising edges", checks, edges);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
