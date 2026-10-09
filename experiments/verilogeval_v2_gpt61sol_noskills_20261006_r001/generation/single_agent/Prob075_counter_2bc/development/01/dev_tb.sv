`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg train_valid = 0;
    reg train_taken = 0;
    wire [1:0] state;
    integer expected;
    integer checks = 0;
    integer i;
    integer j;
    TopModule dut (.clk(clk), .areset(areset),
                   .train_valid(train_valid), .train_taken(train_taken),
                   .state(state));
    always #5 clk = ~clk;

    task verify;
        begin
            if (state !== expected[1:0])
                $fatal(1, "time=%0t expected=%0d actual=%b", $time, expected, state);
            checks = checks + 1;
        end
    endtask

    task step(input reg valid, input reg taken);
        begin
            @(negedge clk);
            train_valid = valid;
            train_taken = taken;
            #1;
            verify(); // No update when training inputs change between rising edges.
            @(posedge clk);
            if (areset) expected = 1;
            else if (valid && taken && expected < 3) expected = expected + 1;
            else if (valid && !taken && expected > 0) expected = expected - 1;
            #1;
            verify();
        end
    endtask

    initial begin
        // Establish state by an asynchronous reset between clock edges.
        #2;
        areset = 1;
        expected = 1;
        #1;
        verify();
        @(posedge clk);
        #1;
        verify();
        @(negedge clk);
        areset = 0;
        #1;
        verify();

        // Traverse both limits repeatedly and check hold with either direction.
        for (i = 0; i < 6; i = i + 1) step(1, 1);
        step(0, 0);
        step(0, 1);
        for (i = 0; i < 6; i = i + 1) step(1, 0);
        step(0, 0);
        step(0, 1);

        // Reset from the lower limit while training is active; hold reset
        // over multiple clock edges and then resume decrementing.
        @(negedge clk);
        train_valid = 1;
        train_taken = 0;
        #2;
        areset = 1;
        expected = 1;
        #1;
        verify();
        step(1, 0);
        step(1, 1);
        @(negedge clk);
        areset = 0;
        #1;
        verify();
        step(1, 0);

        // Exercise every state with all four valid/taken combinations.
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                step(1, 0);
                step(1, 0);
                step(1, 0);
                repeat (i) step(1, 1);
                step(j[1], j[0]);
            end
        end
        $display("PASS: %0d counter checks", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
