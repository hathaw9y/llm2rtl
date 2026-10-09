`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic bump_left = 0, bump_right = 0;
    wire walk_left, walk_right;
    bit expected_right;
    integer checks = 0;
    integer state_index, inputs_index, repeat_index;

    TopModule dut (.clk(clk), .areset(areset), .bump_left(bump_left),
                   .bump_right(bump_right), .walk_left(walk_left),
                   .walk_right(walk_right));
    always #5 clk = ~clk;

    task automatic check_outputs;
        begin
            checks = checks + 1;
            if ({walk_left, walk_right} !==
                (expected_right ? 2'b01 : 2'b10))
                $fatal(1, "Mismatch time=%0t expected_right=%b actual=%b%b",
                       $time, expected_right, walk_left, walk_right);
        end
    endtask

    // Explicit original-problem transition table, independent of DUT encoding.
    task automatic clock_step(input bit left_bump, input bit right_bump);
        begin
            @(negedge clk);
            bump_left = left_bump;
            bump_right = right_bump;
            #1;
            check_outputs(); // Moore outputs must not respond to input changes.
            @(posedge clk);
            if (areset) expected_right = 0;
            else begin
                case ({expected_right, left_bump, right_bump})
                    3'b000, 3'b001: expected_right = 0;
                    3'b010, 3'b011: expected_right = 1;
                    3'b100, 3'b110: expected_right = 1;
                    3'b101, 3'b111: expected_right = 0;
                endcase
            end
            #1;
            check_outputs();
        end
    endtask

    task automatic reset_between_edges;
        begin
            @(negedge clk);
            bump_left = 0;
            bump_right = 0;
            #2;
            areset = 1;
            expected_right = 0;
            #1;
            check_outputs(); // Must reset before the next positive clock edge.
            #1;
            areset = 0;
            #0.5;
            check_outputs();
        end
    endtask

    initial begin
        // No specified startup value: establish the state with asynchronous reset.
        #2;
        areset = 1;
        expected_right = 0;
        #1;
        check_outputs();
        #1;
        areset = 0;
        for (state_index = 0; state_index < 2; state_index = state_index + 1) begin
            for (inputs_index = 0; inputs_index < 4; inputs_index = inputs_index + 1) begin
                reset_between_edges();
                if (state_index == 1) clock_step(1, 0);
                clock_step(inputs_index[1], inputs_index[0]);
            end
        end
        // Both bumps must toggle repeatedly, rather than favor one direction.
        for (repeat_index = 0; repeat_index < 10; repeat_index = repeat_index + 1)
            clock_step(1, 1);
        clock_step(1, 0); // Establish right before interrupting it with reset.
        if (!expected_right) clock_step(1, 0);
        reset_between_edges();
        // Reset dominates obstacles across multiple clocks while held high.
        @(negedge clk);
        areset = 1;
        expected_right = 0;
        #1;
        check_outputs();
        clock_step(1, 1);
        clock_step(1, 0);
        @(negedge clk);
        bump_left = 0;
        bump_right = 0;
        areset = 0;
        #1;
        check_outputs();
        clock_step(1, 0);
        clock_step(0, 0);
        clock_step(1, 0);
        clock_step(0, 1);
        clock_step(0, 1);
        $display("PASS: %0d output checks", checks);
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Timeout");
    end
endmodule
