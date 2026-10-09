`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic bump_left = 0, bump_right = 0, ground = 1;
    wire walk_left, walk_right, aaah;
    // Independent behavioral oracle: remembered direction and airborne flag.
    bit direction_right = 0;
    bit falling = 0;
    integer checks = 0;
    integer state_index, input_index, sequence_index;
    TopModule dut (.*);

    task automatic check_outputs;
        logic [2:0] expected;
        begin
            expected = {(!falling && !direction_right),
                        (!falling && direction_right), falling};
            if ({walk_left, walk_right, aaah} !== expected)
                $fatal(1, "Mismatch t=%0t dir=%b falling=%b expected=%b actual=%b",
                       $time, direction_right, falling, expected,
                       {walk_left, walk_right, aaah});
            checks = checks + 1;
        end
    endtask

    task automatic reset_machine;
        begin
            // Assert between edges, and check without a clock edge.
            clk = 0;
            #2;
            areset = 1;
            direction_right = 0;
            falling = 0;
            #1;
            check_outputs();
            clk = 1;
            #1;
            check_outputs();
            clk = 0;
            areset = 0;
            #1;
            check_outputs();
        end
    endtask

    task automatic step(input bit g, input bit bl, input bit br);
        begin
            clk = 0;
            ground = g;
            bump_left = bl;
            bump_right = br;
            #2;
            // A Moore output must remain unchanged before the active edge.
            check_outputs();
            if (falling) begin
                if (g) falling = 0;
            end else if (!g) begin
                falling = 1;
            end else if ((!direction_right && bl) || (direction_right && br)) begin
                direction_right = !direction_right;
            end
            clk = 1;
            #1;
            check_outputs();
            clk = 0;
            #1;
            check_outputs();
        end
    endtask

    initial begin
        // No initial-state expectation is imposed before the specified reset.
        reset_machine();
        // Every reachable state, all eight combinations of the three inputs.
        for (state_index = 0; state_index < 4; state_index = state_index + 1) begin
            for (input_index = 0; input_index < 8; input_index = input_index + 1) begin
                reset_machine();
                if (state_index % 2 == 1) step(1, 1, 0);
                if (state_index >= 2) step(0, 1, 1);
                step(input_index[2], input_index[1], input_index[0]);
                // Landing with both bumps ignores bumps, then the next edge switches.
                step(1, 1, 1);
                step(1, 1, 1);
            end
        end
        // Long fall with varied bumps and landing in remembered right direction.
        reset_machine();
        step(1, 1, 0);
        step(0, 1, 1);
        for (sequence_index = 0; sequence_index < 16; sequence_index = sequence_index + 1)
            step(0, sequence_index[0], sequence_index[1]);
        step(1, 1, 1);
        // Reset during a fall, even though ground remains absent.
        step(0, 0, 0);
        reset_machine();
        step(0, 1, 1);
        step(1, 1, 1);
        // Deterministic mixed sequence for repeated transitions.
        for (sequence_index = 0; sequence_index < 256; sequence_index = sequence_index + 1)
            step(sequence_index[0] ^ sequence_index[3],
                 sequence_index[1] ^ sequence_index[4],
                 sequence_index[2] ^ sequence_index[5]);
        $display("PASS: %0d output checks", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
