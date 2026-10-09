`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic train_valid = 0;
    logic train_taken = 0;
    wire [1:0] state;
    integer expected;
    integer checks = 0;
    integer s, v, t, n;
    TopModule dut (.clk(clk), .areset(areset),
        .train_valid(train_valid), .train_taken(train_taken), .state(state));

    task automatic check_state;
        begin
            if (state !== expected[1:0])
                $fatal(1, "Mismatch at %0t: expected %0d got %b", $time, expected, state);
            checks = checks + 1;
        end
    endtask

    // Explicit transition table is independent of DUT arithmetic.
    task automatic step(input logic valid_value, input logic taken_value);
        begin
            train_valid = valid_value;
            train_taken = taken_value;
            #2;
            check_state(); // Changing training controls cannot change state.
            if (areset) expected = 1;
            else if (valid_value) begin
                case (expected)
                    0: if (taken_value) expected = 1; else expected = 0;
                    1: if (taken_value) expected = 2; else expected = 0;
                    2: if (taken_value) expected = 3; else expected = 1;
                    3: if (taken_value) expected = 3; else expected = 2;
                    default: $fatal(1, "Invalid oracle state");
                endcase
            end
            clk = 1;
            #1;
            check_state(); // Sample after nonblocking assignments.
            #2;
            clk = 0;
            #1;
            check_state(); // Falling clock edge must hold state.
        end
    endtask

    task automatic reset_counter;
        begin
            #1;
            areset = 1;
            expected = 1;
            #1;
            check_state(); // No clock edge: reset must be asynchronous.
            areset = 0;
            #1;
            check_state(); // Reset release must hold state.
        end
    endtask

    initial begin
        // No pre-reset value is prescribed by the problem.
        reset_counter();
        for (s = 0; s < 4; s = s + 1) begin
            for (v = 0; v < 2; v = v + 1) begin
                for (t = 0; t < 2; t = t + 1) begin
                    reset_counter();
                    if (s == 0) step(1, 0);
                    else for (n = 1; n < s; n = n + 1) step(1, 1);
                    step(v != 0, t != 0);
                end
            end
        end
        // Repeated saturation, then traverse the entire range in both directions.
        reset_counter();
        repeat (8) step(1, 1);
        repeat (8) step(1, 0);
        repeat (8) step(1, 1);
        repeat (4) begin step(0, 0); step(0, 1); end
        // Reset during training, held through multiple rising clock edges.
        #1; areset = 1; expected = 1;
        #1; check_state();
        step(1, 1);
        step(1, 0);
        areset = 0;
        #1; check_state();
        step(1, 0);
        reset_counter();
        step(1, 1);
        $display("PASS: saturating counter, %0d checks", checks);
        $finish;
    end
    initial begin
        #5000;
        $fatal(1, "Timeout");
    end
endmodule
