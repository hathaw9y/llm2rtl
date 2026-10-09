`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg bump_left = 0, bump_right = 0, ground = 1;
    wire walk_left, walk_right, aaah;
    reg direction_right, falling;
    integer checks = 0;
    integer sequence_id, step_id, symbol, code;

    TopModule dut (
        .clk(clk), .areset(areset),
        .bump_left(bump_left), .bump_right(bump_right), .ground(ground),
        .walk_left(walk_left), .walk_right(walk_right), .aaah(aaah)
    );
    always #5 clk = ~clk;

    task compare;
        reg [2:0] expected;
        begin
            if (falling) expected = 3'b001;
            else if (direction_right) expected = 3'b010;
            else expected = 3'b100;
            if ({walk_left, walk_right, aaah} !== expected)
                $fatal(1, "Mismatch at %0t: got %b expected %b, inputs g/l/r=%b%b%b",
                       $time, {walk_left, walk_right, aaah}, expected,
                       ground, bump_left, bump_right);
            checks = checks + 1;
        end
    endtask

    task reset_machine;
        begin
            @(negedge clk);
            #1 areset = 1;
            direction_right = 0;
            falling = 0;
            #1 compare;
            @(posedge clk);
            #1 compare;
            @(negedge clk);
            #1 areset = 0;
            #1 compare;
        end
    endtask

    // Oracle holds direction independently from whether the lemming is falling.
    task tick(input reg g, input reg bl, input reg br);
        begin
            @(negedge clk);
            ground = g;
            bump_left = bl;
            bump_right = br;
            #1 compare; // Moore outputs must not react to inputs before clock.
            @(posedge clk);
            if (falling) begin
                if (g) falling = 0; // Landing ignores bumps.
            end else if (!g) begin
                falling = 1; // Fall entry ignores bumps.
            end else begin
                if ((!direction_right && bl) || (direction_right && br))
                    direction_right = !direction_right;
            end
            #1 compare;
        end
    endtask

    initial begin
        // No expectations before reset: the original gives no power-up state.
        reset_machine;
        tick(1, 0, 1); // Opposite-side bump does not turn left walker.
        tick(1, 1, 1); // Both bumps turn.
        tick(1, 1, 0); // Opposite-side bump does not turn right walker.
        tick(0, 1, 1); // Fall takes priority, retaining right.
        tick(0, 0, 1);
        tick(0, 1, 0);
        tick(1, 1, 1); // Landing ignores bumps, still right.
        tick(1, 1, 1); // Following walking edge turns left.
        tick(0, 1, 1); // Fall retains left.
        tick(0, 1, 1);
        tick(1, 1, 1); // Landing retains left.
        tick(1, 1, 0);
        reset_machine; // Asynchronous reset from right walking.
        tick(0, 1, 1);
        reset_machine; // Asynchronous reset from left falling.
        tick(1, 1, 0);
        tick(0, 1, 1);
        reset_machine; // Asynchronous reset from right falling.

        // Every four-cycle sequence of the eight possible input combinations.
        for (sequence_id = 0; sequence_id < 4096; sequence_id = sequence_id + 1) begin
            ground = 1;
            bump_left = 0;
            bump_right = 0;
            reset_machine;
            code = sequence_id;
            for (step_id = 0; step_id < 4; step_id = step_id + 1) begin
                symbol = code % 8;
                code = code / 8;
                tick((symbol >> 2) & 1, (symbol >> 1) & 1, symbol & 1);
            end
        end
        $display("PASS: %0d Moore output checks, directed cases and exhaustive four-cycle sequences", checks);
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "Bounded timeout");
    end
endmodule
