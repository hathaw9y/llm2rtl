`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg train_valid = 0;
    reg train_taken = 0;
    wire [1:0] state;
    integer expected;
    integer checks = 0;
    integer s, v, t, i;
    TopModule dut (.clk(clk), .areset(areset), .train_valid(train_valid),
                   .train_taken(train_taken), .state(state));

    task check_state;
        begin
            if (state !== expected[1:0])
                $fatal(1, "Mismatch time=%0t expected=%0d actual=%b", $time, expected, state);
            checks = checks + 1;
        end
    endtask

    task cycle(input reg valid_value, input reg taken_value);
        begin
            train_valid = valid_value;
            train_taken = taken_value;
            #2;
            check_state(); // Input changes do not update the counter.
            clk = 1;
            if (areset) expected = 1;
            else if (valid_value) begin
                if (taken_value && expected < 3) expected = expected + 1;
                else if (!taken_value && expected > 0) expected = expected - 1;
            end
            #1;
            check_state();
            #2;
            clk = 0;
            #1;
            check_state();
        end
    endtask

    task reset_counter;
        begin
            // Clock is low; reset must work without any clock edge.
            #1;
            areset = 1;
            expected = 1;
            #1;
            check_state();
            cycle(1, 1);
            cycle(1, 0);
            areset = 0;
            #1;
            check_state(); // Reset deassertion alone must not train.
        end
    endtask

    initial begin
        #1;
        reset_counter();
        for (s = 0; s < 4; s = s + 1) begin
            for (v = 0; v < 2; v = v + 1) begin
                for (t = 0; t < 2; t = t + 1) begin
                    reset_counter();
                    if (s == 0) cycle(1, 0);
                    for (i = 1; i < s; i = i + 1) cycle(1, 1);
                    cycle(v != 0, t != 0);
                end
            end
        end
        reset_counter();
        repeat (8) cycle(1, 1);
        repeat (8) cycle(0, 0);
        repeat (8) cycle(1, 0);
        repeat (8) cycle(0, 1);
        reset_counter();
        for (i = 0; i < 128; i = i + 1)
            cycle((i % 5) != 0, ((i * 7 + i / 3) % 11) < 6);
        // Also exercise reset while clock is already high.
        clk = 1;
        if (train_valid) begin
            if (train_taken && expected < 3) expected = expected + 1;
            else if (!train_taken && expected > 0) expected = expected - 1;
        end
        #1;
        check_state();
        areset = 1;
        expected = 1;
        #1;
        check_state();
        areset = 0;
        #1;
        check_state();
        clk = 0;
        #1;
        check_state();
        $display("PASS counter checks=%0d", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
