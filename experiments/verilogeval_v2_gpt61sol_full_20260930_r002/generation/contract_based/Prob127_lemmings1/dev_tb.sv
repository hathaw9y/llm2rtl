`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic bump_left = 0, bump_right = 0;
    wire walk_left, walk_right;
    bit expected_left;
    bit initialized = 0;
    integer checks = 0;
    TopModule dut (.clk(clk), .areset(areset), .bump_left(bump_left),
                   .bump_right(bump_right), .walk_left(walk_left), .walk_right(walk_right));
    always #5 clk = ~clk;

    task automatic check_outputs;
        if (initialized) begin
            if ({walk_left, walk_right} !== {expected_left, !expected_left})
                $fatal(1, "Mismatch t=%0t expected left=%b got=%b%b", $time, expected_left, walk_left, walk_right);
            checks = checks + 1;
        end
    endtask

    // Oracle uses direction-dependent collisions from the original description.
    always @(posedge clk or posedge areset) begin
        if (areset) begin
            expected_left = 1;
            initialized = 1;
        end else if (initialized) begin
            if ((expected_left && bump_left) || (!expected_left && bump_right))
                expected_left = !expected_left;
        end
        #1;
        check_outputs();
    end

    task automatic step(input bit bl, input bit br);
        @(negedge clk);
        bump_left = bl;
        bump_right = br;
        #1;
        check_outputs(); // Moore outputs must hold despite changing bump inputs.
        @(posedge clk);
        #2;
        check_outputs();
    endtask

    initial begin
        // Assert away from clock edges to prove asynchronous reset.
        #2; areset = 1;
        #1; check_outputs();
        #9; areset = 0;
        #1; check_outputs();
        // Every combination from each direction, including opposite-side bumps.
        for (integer direction = 0; direction < 2; direction = direction + 1) begin
            for (integer bumps = 0; bumps < 4; bumps = bumps + 1) begin
                step(0, 1); // establish left regardless of prior direction
                if (direction == 1) step(1, 0); // establish right
                step((bumps & 1) != 0, (bumps & 2) != 0);
            end
        end
        repeat (8) step(1, 1);
        step(1, 0); // ensure right before asynchronous reset
        @(negedge clk);
        #2; areset = 1;
        #2; check_outputs();
        // Hold reset across multiple edges with both bumps asserted.
        step(1, 1);
        step(1, 1);
        @(negedge clk);
        #2; areset = 0;
        #1; check_outputs();
        step(0, 0);
        step(1, 1);
        step(0, 0);
        $display("PASS: Lemmings direction, reset and Moore checks (%0d comparisons)", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
