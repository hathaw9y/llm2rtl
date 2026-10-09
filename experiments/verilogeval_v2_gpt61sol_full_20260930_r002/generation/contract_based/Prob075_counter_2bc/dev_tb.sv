`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic train_valid = 0;
    logic train_taken = 0;
    wire [1:0] state;
    integer expected;
    integer checks = 0;
    integer target, valid_bit, taken_bit, k;
    TopModule dut (.clk(clk), .areset(areset), .train_valid(train_valid),
                   .train_taken(train_taken), .state(state));
    always #5 clk = ~clk;

    task automatic check_state;
        begin
            if (state !== expected[1:0])
                $fatal(1, "Mismatch at %0t: expected %0d got %b", $time, expected, state);
            checks = checks + 1;
        end
    endtask

    task automatic step(input bit valid_value, input bit taken_value);
        begin
            @(negedge clk);
            train_valid = valid_value;
            train_taken = taken_value;
            #1;
            check_state();
            @(posedge clk);
            if (areset) expected = 1;
            else if (valid_value) begin
                if (taken_value && expected < 3) expected = expected + 1;
                else if (!taken_value && expected > 0) expected = expected - 1;
            end
            #1;
            check_state();
            #2;
            check_state();
        end
    endtask

    task automatic async_reset;
        begin
            @(negedge clk);
            #2;
            areset = 1;
            expected = 1;
            #1;
            check_state();
            @(posedge clk);
            #1;
            check_state();
            @(negedge clk);
            #1;
            train_valid = 0;
            areset = 0;
            #1;
            check_state();
        end
    endtask

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end

    initial begin
        // No specification-defined power-up value; establish it with reset.
        #2;
        areset = 1;
        expected = 1;
        #1;
        check_state();
        #3;
        check_state();
        areset = 0;
        #1;
        check_state();

        // Reach each state then cover both directions and disabled training.
        for (target = 0; target < 4; target = target + 1) begin
            for (valid_bit = 0; valid_bit < 2; valid_bit = valid_bit + 1) begin
                for (taken_bit = 0; taken_bit < 2; taken_bit = taken_bit + 1) begin
                    async_reset();
                    if (target == 0) step(1, 0);
                    else for (k = 1; k < target; k = k + 1) step(1, 1);
                    step(valid_bit != 0, taken_bit != 0);
                end
            end
        end
        // Repeated boundary attempts must saturate rather than wrap.
        repeat (6) step(1, 1);
        repeat (4) step(0, 0);
        repeat (6) step(1, 0);
        repeat (4) step(0, 1);
        // Assert reset during active decrement at the lower bound.
        train_valid = 1;
        train_taken = 0;
        async_reset();
        step(1, 0);
        // Reset at the upper bound during active increment.
        repeat (4) step(1, 1);
        async_reset();
        step(1, 1);
        $display("PASS: %0d counter checks", checks);
        $finish;
    end
endmodule
