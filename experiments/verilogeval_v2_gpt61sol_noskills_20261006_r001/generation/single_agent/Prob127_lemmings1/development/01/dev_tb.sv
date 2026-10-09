`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg bump_left = 0;
    reg bump_right = 0;
    wire walk_left, walk_right;
    reg expected_right;
    integer checks = 0;
    integer direction, inputs, repetition;

    TopModule dut(.clk(clk), .areset(areset), .bump_left(bump_left),
                  .bump_right(bump_right), .walk_left(walk_left),
                  .walk_right(walk_right));

    task check_outputs;
        begin
            if (walk_right !== expected_right || walk_left !== !expected_right)
                $fatal(1, "Mismatch at %0t: expected right=%b, got left=%b right=%b",
                       $time, expected_right, walk_left, walk_right);
            checks = checks + 1;
        end
    endtask

    task reset_async;
        begin
            clk = 0;
            #2;
            areset = 1;
            expected_right = 0;
            #1;
            check_outputs;
            // Reset must dominate obstacles and remain active on clock edges.
            bump_left = 1;
            bump_right = 1;
            clk = 1;
            #1;
            check_outputs;
            clk = 0;
            #1;
            areset = 0;
            #1;
            check_outputs;
        end
    endtask

    task step(input reg left_bump, input reg right_bump);
        begin
            clk = 0;
            bump_left = left_bump;
            bump_right = right_bump;
            #2;
            check_outputs; // Inputs must not change Moore outputs between edges.
            if (areset) expected_right = 0;
            else if ((!expected_right && left_bump) ||
                     (expected_right && right_bump))
                expected_right = !expected_right;
            clk = 1;
            #1;
            check_outputs;
            clk = 0;
            #1;
            check_outputs;
        end
    endtask

    initial begin
        // The specification does not prescribe a state before reset.
        reset_async;
        for (direction = 0; direction < 2; direction = direction + 1) begin
            for (inputs = 0; inputs < 4; inputs = inputs + 1) begin
                reset_async;
                if (direction == 1) step(1, 0);
                step((inputs & 2) != 0, (inputs & 1) != 0);
            end
        end
        reset_async;
        step(1, 0); // Asynchronous reset is exercised while walking right.
        reset_async;
        for (repetition = 0; repetition < 16; repetition = repetition + 1)
            step(1, 1);
        for (repetition = 0; repetition < 8; repetition = repetition + 1) begin
            step(1, 0);
            step(1, 0);
            step(0, 0);
            step(0, 1);
            step(0, 1);
            step(0, 0);
        end
        $display("PASS: %0d output checks", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
