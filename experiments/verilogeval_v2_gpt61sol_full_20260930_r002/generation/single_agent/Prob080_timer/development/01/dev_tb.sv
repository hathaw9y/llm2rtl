`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic load = 1'b0;
    logic [9:0] data = 10'd0;
    wire tc;
    integer remaining = -1;
    integer checked_edges = 0;
    integer value;
    integer cycle;
    integer seed = 12345;
    integer random_word;

    TopModule dut (.clk(clk), .load(load), .data(data), .tc(tc));
    always #5 clk = ~clk;

    task automatic check_output;
        logic expected;
        begin
            if (remaining < 0)
                expected = 1'bx;
            else
                expected = (remaining == 0);
            if (tc !== expected)
                $fatal(1, "tc mismatch at %0t: remaining=%0d expected=%b actual=%b", $time, remaining, expected, tc);
        end
    endtask

    // Inputs change on falling edges. Check both before and after the
    // positive edge, allowing the DUT's nonblocking update to settle.
    task automatic step(input logic next_load, input logic [9:0] next_data);
        begin
            @(negedge clk);
            load = next_load;
            data = next_data;
            #1;
            check_output();
            @(posedge clk);
            check_output();
            if (next_load)
                remaining = next_data;
            else if (remaining > 0)
                remaining = remaining - 1;
            #1;
            check_output();
            checked_edges = checked_edges + 1;
        end
    endtask

    initial begin
        #1;
        check_output();
        repeat (3) step(1'b0, 10'd777);
        step(1'b1, 10'd0);
        repeat (4) step(1'b0, 10'd1023);
        step(1'b1, 10'd1);
        step(1'b0, 10'd0);
        step(1'b0, 10'd0);

        // Interrupt an active timer, including loading zero and holding load.
        step(1'b1, 10'd20);
        repeat (5) step(1'b0, 10'd3);
        step(1'b1, 10'd2);
        step(1'b1, 10'd4);
        step(1'b0, 10'd0);
        step(1'b1, 10'd0);
        step(1'b0, 10'd900);
        step(1'b1, 10'd1023);
        repeat (7) step(1'b1, 10'd1023);
        step(1'b1, 10'd1);
        step(1'b0, 10'd100);

        // Every legal duration: assert timeout exactly after that many edges,
        // then confirm saturation instead of underflow.
        for (value = 0; value < 1024; value = value + 1) begin
            step(1'b1, value[9:0]);
            for (cycle = 0; cycle < value; cycle = cycle + 1)
                step(1'b0, 10'd1023);
            repeat (2) step(1'b0, 10'd1);
        end

        // Repeated arbitrary interruptions and data changes with load low.
        for (cycle = 0; cycle < 2000; cycle = cycle + 1) begin
            random_word = $random(seed);
            step((random_word & 7) == 0, random_word[19:10]);
        end
        step(1'b1, 10'd10);
        repeat (15) step(1'b0, 10'd1023);
        $display("PASS timer: %0d checked edges, all 1024 durations", checked_edges);
        $finish;
    end

    initial begin
        #12000000;
        $fatal(1, "Timeout");
    end
endmodule
