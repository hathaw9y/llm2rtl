`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic bump_left = 0, bump_right = 0, ground = 1;
    wire walk_left, walk_right, aaah;
    bit direction_right, falling;
    integer checks = 0;
    integer s, combination, repetition;
    TopModule dut (.*);
    always #5 clk = ~clk;

    task automatic check_outputs;
        logic [2:0] expected;
        begin
            expected = {(!falling && !direction_right),
                        (!falling && direction_right), falling};
            if ({walk_left, walk_right, aaah} !== expected)
                $fatal(1, "Mismatch t=%0t expected=%b actual=%b", $time,
                       expected, {walk_left, walk_right, aaah});
            checks = checks + 1;
        end
    endtask

    task automatic reset_machine;
        begin
            @(negedge clk);
            #2;
            areset = 1;
            direction_right = 0;
            falling = 0;
            #1;
            check_outputs(); // asynchronous reset without a clock edge
            @(posedge clk);
            #1;
            check_outputs(); // held reset dominates all inputs
            @(negedge clk);
            areset = 0;
            #1;
            check_outputs(); // deassertion does not change state
        end
    endtask

    task automatic step(input bit g, input bit bl, input bit br);
        begin
            @(negedge clk);
            ground = g;
            bump_left = bl;
            bump_right = br;
            #1;
            check_outputs(); // Moore outputs cannot respond to raw inputs
            @(posedge clk);
            // Oracle directly implements remembered direction and falling rules.
            if (falling) begin
                if (g) falling = 0;
            end else if (!g) begin
                falling = 1;
            end else begin
                if ((!direction_right && bl) || (direction_right && br))
                    direction_right = !direction_right;
            end
            #1;
            check_outputs();
        end
    endtask

    initial begin
        // Every possible input combination from each reachable behavioral state.
        for (s = 0; s < 4; s = s + 1) begin
            for (combination = 0; combination < 8; combination = combination + 1) begin
                reset_machine();
                step(1, 0, 0);
                if (s == 1 || s == 3) step(1, 1, 0);
                if (s >= 2) step(0, 1, 1);
                step(combination[2], combination[1], combination[0]);
            end
        end
        // Extended falls and simultaneous bumps at entry and landing, both directions.
        reset_machine();
        for (s = 0; s < 2; s = s + 1) begin
            step(0, 1, 1);
            for (repetition = 0; repetition < 12; repetition = repetition + 1)
                step(0, repetition[0], repetition[1]);
            step(1, 1, 1);
            step(1, 1, 1);
        end
        // Repeated both-side reversals.
        for (repetition = 0; repetition < 20; repetition = repetition + 1)
            step(1, 1, 1);
        // Assert reset from every walking/falling state, including ground absent.
        for (s = 0; s < 4; s = s + 1) begin
            reset_machine();
            step(1, 0, 0);
            if (s == 1 || s == 3) step(1, 1, 0);
            if (s >= 2) step(0, 1, 1);
            reset_machine();
        end
        $display("PASS %0d output checks", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
