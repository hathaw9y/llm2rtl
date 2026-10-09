`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg bump_left = 0, bump_right = 0, ground = 1, dig = 0;
    wire walk_left, walk_right, aaah, digging;
    TopModule dut (.*);
    always #5 clk = ~clk;

    // Independent oracle: activity and saved direction, not DUT state encoding.
    integer activity = 0; // 0 walking, 1 falling, 2 digging
    reg rightward = 0;
    integer checks = 0;
    integer s, bits, k;
    reg [3:0] expected;

    task check_outputs;
        begin
            expected = 4'b0000;
            if (activity == 0) begin
                if (rightward) expected[2] = 1;
                else expected[3] = 1;
            end
            else if (activity == 1) expected[1] = 1;
            else expected[0] = 1;
            if ({walk_left, walk_right, aaah, digging} !== expected)
                $fatal(1, "Mismatch t=%0t activity=%0d direction=%0d expected=%b got=%b",
                    $time, activity, rightward, expected,
                    {walk_left, walk_right, aaah, digging});
            checks = checks + 1;
        end
    endtask

    task reset_machine;
        begin
            @(negedge clk);
            areset = 0;
            #1;
            areset = 1;
            activity = 0;
            rightward = 0;
            #1;
            check_outputs; // reset takes effect without a clock edge
            @(posedge clk);
            #1;
            check_outputs; // reset dominates active inputs
            @(negedge clk);
            areset = 0;
            #1;
            check_outputs;
        end
    endtask

    task step(input reg g, input reg d, input reg bl, input reg br);
        begin
            @(negedge clk);
            ground = g;
            dig = d;
            bump_left = bl;
            bump_right = br;
            #1;
            check_outputs; // Moore outputs cannot respond to inputs before edge
            @(posedge clk);
            if (activity == 0) begin
                if (!g) activity = 1;
                else if (d) activity = 2;
                else if ((!rightward && bl) || (rightward && br))
                    rightward = !rightward;
            end
            else if (activity == 1) begin
                if (g) activity = 0;
            end
            else begin
                if (!g) activity = 1;
            end
            #1;
            check_outputs;
        end
    endtask

    task reach_state(input integer target);
        begin
            ground = 1;
            dig = 0;
            bump_left = 0;
            bump_right = 0;
            reset_machine;
            if (target % 2 == 1) step(1, 0, 1, 0);
            if (target / 2 == 1) step(0, 0, 0, 0);
            if (target / 2 == 2) step(1, 1, 0, 0);
        end
    endtask

    initial begin
        // Every binary combination from all six reachable logical states.
        for (s = 0; s < 6; s = s + 1) begin
            for (bits = 0; bits < 16; bits = bits + 1) begin
                reach_state(s);
                step(bits[3], bits[2], bits[1], bits[0]);
                // Follow through falling/digging to observe retained direction.
                step(0, 1, 1, 1);
                step(1, 1, 1, 1);
                step(1, 0, 0, 0);
            end
        end
        // Dig remains active after dig deasserts; falling can last arbitrarily.
        for (s = 0; s < 2; s = s + 1) begin
            reach_state(s);
            step(1, 1, 1, 1);
            for (k = 0; k < 8; k = k + 1) step(1, 0, 1, 1);
            step(0, 1, 1, 1);
            for (k = 0; k < 8; k = k + 1) step(0, 1, 1, 1);
            step(1, 1, 1, 1);
        end
        // Reset from each activity/direction and with adverse input conditions.
        for (s = 0; s < 6; s = s + 1) begin
            reach_state(s);
            ground = 0;
            dig = 1;
            bump_left = 1;
            bump_right = 1;
            reset_machine;
            step(1, 0, 0, 0);
        end
        $display("PASS: %0d Moore, transition, direction and asynchronous reset checks", checks);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Bounded timeout");
    end
endmodule
