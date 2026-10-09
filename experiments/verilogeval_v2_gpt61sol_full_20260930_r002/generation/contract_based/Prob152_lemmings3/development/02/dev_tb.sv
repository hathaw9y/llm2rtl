`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic bump_left = 0, bump_right = 0, ground = 1, dig = 0;
    wire walk_left, walk_right, aaah, digging;
    TopModule dut(.*);
    always #5 clk = ~clk;

    // Independent oracle: activity plus remembered heading, rather than DUT encoding.
    integer activity = 0; // 0 walking, 1 falling, 2 digging
    bit rightward = 0;
    integer checks = 0;
    integer s, v, j;

    task automatic check_outputs;
        logic [3:0] expected;
        begin
            expected = {activity == 0 && !rightward,
                        activity == 0 && rightward,
                        activity == 1, activity == 2};
            if ({walk_left, walk_right, aaah, digging} !== expected)
                $fatal(1, "Mismatch t=%0t activity=%0d rightward=%0d got=%b expected=%b",
                       $time, activity, rightward,
                       {walk_left, walk_right, aaah, digging}, expected);
            checks = checks + 1;
        end
    endtask

    task automatic reset_machine;
        begin
            @(negedge clk);
            #1 areset = 1;
            bump_left = 0;
            bump_right = 0;
            ground = 1;
            dig = 0;
            activity = 0;
            rightward = 0;
            #1 check_outputs(); // asynchronous: no rising clock since reset assertion
            @(posedge clk);
            #1 check_outputs();
            @(negedge clk);
            #1 areset = 0;
            #1 check_outputs(); // deassertion causes no transition
        end
    endtask

    task automatic step(input bit bl, input bit br, input bit gr, input bit dg);
        begin
            @(negedge clk);
            bump_left = bl;
            bump_right = br;
            ground = gr;
            dig = dg;
            #1 check_outputs(); // inputs alone cannot alter Moore outputs
            @(posedge clk);
            if (areset) begin
                activity = 0;
                rightward = 0;
            end else begin
                case (activity)
                    0: begin
                        if (!gr) activity = 1;
                        else if (dg) activity = 2;
                        else if ((!rightward && bl) || (rightward && br))
                            rightward = !rightward;
                    end
                    1: if (gr) activity = 0;
                    2: if (!gr) activity = 1;
                endcase
            end
            #1 check_outputs();
        end
    endtask

    task automatic reach(input integer target);
        begin
            // target 0/1 walk left/right, 2/3 fall left/right, 4/5 dig left/right
            reset_machine();
            if (target % 2) step(1, 0, 1, 0);
            if (target / 2 == 1) step(0, 0, 0, 0);
            if (target / 2 == 2) step(0, 0, 1, 1);
        end
    endtask

    initial begin
        // Start with reset before any checks; pre-reset behavior is unspecified.
        reset_machine();
        for (s = 0; s < 6; s = s + 1) begin
            for (v = 0; v < 16; v = v + 1) begin
                reach(s);
                step(v[3], v[2], v[1], v[0]);
                // Observe preserved direction on eventual return from dig/fall.
                step(1, 1, 0, 1);
                step(1, 1, 1, 1);
                step(0, 0, 1, 0);
            end
            reach(s);
            reset_machine(); // asynchronous interruption from every activity/direction
        end
        // Long digging, falling, and walking sequences with varying commands.
        for (j = 0; j < 100; j = j + 1) begin
            step(1, 1, 1, 1);
            step(j[0], j[1], 1, 0);
            step(1, 1, 0, 1);
            step(j[1], j[0], 0, 0);
            step(1, 1, 1, 1);
            step(1, 1, 1, 0);
        end
        $display("PASS: independent Lemmings oracle, %0d checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
