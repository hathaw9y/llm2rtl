`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg bump_left = 0, bump_right = 0, ground = 1, dig = 0;
    wire walk_left, walk_right, aaah, digging;
    TopModule dut(.*);
    always #5 clk = ~clk;

    // Independent activity/direction model, rather than DUT state encoding.
    localparam WALK = 0, FALL = 1, DIGGING = 2, SPLAT = 3;
    integer activity, fall_intervals, comparisons = 0;
    reg rightward;
    reg model_valid = 0;
    reg [3:0] expected;
    integer i, j, length, direction, use_dig;
    reg [31:0] rng = 32'h54c120a7;

    task check_outputs;
        begin
            expected = 4'b0000;
            case (activity)
                WALK: if (rightward) expected = 4'b0100;
                      else expected = 4'b1000;
                FALL: expected = 4'b0010;
                DIGGING: expected = 4'b0001;
                SPLAT: expected = 4'b0000;
                default: $fatal(1, "Invalid oracle activity");
            endcase
            if ({walk_left,walk_right,aaah,digging} !== expected)
                $fatal(1, "Mismatch at %0t: actual=%b expected=%b activity=%0d direction=%b duration=%0d inputs=%b%b%b%b",
                       $time, {walk_left,walk_right,aaah,digging}, expected,
                       activity, rightward, fall_intervals, ground,dig,bump_left,bump_right);
            comparisons = comparisons + 1;
        end
    endtask

    always @(posedge clk or posedge areset) begin
        if (areset) begin
            model_valid = 1;
            activity = WALK;
            rightward = 0;
            fall_intervals = 0;
        end else if (model_valid) begin
            case (activity)
                WALK: begin
                    if (!ground) begin
                        activity = FALL;
                        fall_intervals = 0;
                    end else if (dig) activity = DIGGING;
                    else if ((!rightward && bump_left) || (rightward && bump_right))
                        rightward = !rightward;
                end
                DIGGING: if (!ground) begin
                    activity = FALL;
                    fall_intervals = 0;
                end
                FALL: begin
                    // This edge completes one full falling-state interval.
                    fall_intervals = fall_intervals + 1;
                    if (ground) begin
                        if (fall_intervals > 20) activity = SPLAT;
                        else activity = WALK;
                    end
                end
                SPLAT: activity = SPLAT;
            endcase
        end
        #1;
        if (model_valid) check_outputs();
    end

    task step(input reg g, input reg d, input reg bl, input reg br);
        begin
            @(negedge clk);
            ground = g; dig = d; bump_left = bl; bump_right = br;
            #1;
            // Input changes must not directly change Moore outputs.
            check_outputs();
            @(posedge clk);
            #2;
        end
    endtask

    task reset_machine;
        begin
            @(negedge clk);
            ground = 1; dig = 0; bump_left = 0; bump_right = 0;
            #2 areset = 1;
            #2;
            if ({walk_left,walk_right,aaah,digging} !== 4'b1000)
                $fatal(1, "Asynchronous reset did not restore left before clock");
            @(negedge clk);
            #1 areset = 0;
        end
    endtask

    initial begin
        // Reset starts between edges; no unspecified power-up assertion.
        reset_machine();
        step(1,0,0,1); // Opposite bump ignored in left direction.
        step(1,0,1,1); // Both bumps reverse.
        step(1,0,1,0); // Opposite bump ignored in right direction.
        step(1,0,1,1);

        // Exhaust all walking input combinations from each direction.
        for (direction = 0; direction < 2; direction = direction + 1) begin
            for (i = 0; i < 16; i = i + 1) begin
                reset_machine();
                if (direction) step(1,0,1,0);
                step(i[3],i[2],i[1],i[0]);
                step(1,1,1,1);
                step(1,0,0,0);
            end
        end

        // Repeat every important fall length, from walk and dig in both directions.
        for (direction = 0; direction < 2; direction = direction + 1) begin
            for (use_dig = 0; use_dig < 2; use_dig = use_dig + 1) begin
                for (j = 0; j < 7; j = j + 1) begin
                    case (j)
                        0: length = 1;
                        1: length = 19;
                        2: length = 20;
                        3: length = 21;
                        4: length = 22;
                        5: length = 32;
                        6: length = 257;
                    endcase
                    reset_machine();
                    if (direction) step(1,0,1,0);
                    if (use_dig) begin
                        step(1,1,1,1);
                        for (i = 0; i < 8; i = i + 1)
                            step(1,i[0],i[1],i[2]);
                    end
                    for (i = 0; i < length; i = i + 1)
                        step(0,1,1,1);
                    step(1,1,1,1); // Landing ignores bump/dig, or splatters.
                    if (length <= 20) begin
                        if (aaah || digging || (walk_right !== (direction != 0)))
                            $fatal(1,"Explicit safe-landing boundary failure length=%0d",length);
                    end else begin
                        if ({walk_left,walk_right,aaah,digging} !== 4'b0000)
                            $fatal(1,"Explicit splatter boundary failure length=%0d",length);
                        for (i = 0; i < 16; i = i + 1)
                            step(i[3],i[2],i[1],i[0]);
                    end
                end
            end
        end
        // Reset interrupts a long fall and sustained digging.
        reset_machine();
        for (i = 0; i < 40; i = i + 1) step(0,0,0,0);
        reset_machine();
        step(1,0,0,0);
        step(1,1,0,0);
        reset_machine();
        step(1,0,0,0);
        // Many separate short falls must not accumulate lifetime duration.
        for (i = 0; i < 30; i = i + 1) begin
            step(0,0,1,1);
            step(1,0,1,1);
        end
        // Reproducible varied sequence with periodic asynchronous resets.
        for (i = 0; i < 2000; i = i + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            if ((i % 97) == 0) reset_machine();
            step(rng[0],rng[1],rng[2],rng[3]);
        end
        $display("PASS: independent original-spec oracle; %0d comparisons",comparisons);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1,"Bounded test timeout");
    end
endmodule
