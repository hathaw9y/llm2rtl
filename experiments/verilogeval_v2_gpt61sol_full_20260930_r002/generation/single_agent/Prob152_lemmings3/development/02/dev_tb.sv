`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg bump_left = 0, bump_right = 0, ground = 1, dig = 0;
    wire walk_left, walk_right, aaah, digging;
    TopModule dut (.*);
    always #5 clk = ~clk;

    // Independent behavioral oracle: activity and retained walking direction.
    integer activity = 0; // 0 walking, 1 falling, 2 digging
    reg direction = 0; // 0 left, 1 right
    integer checks = 0;
    integer s, v, k;
    reg [3:0] expected;
    task check_outputs;
        begin
            expected = 4'b0000;
            if (activity == 1) expected[1] = 1;
            else if (activity == 2) expected[0] = 1;
            else if (direction) expected[2] = 1;
            else expected[3] = 1;
            if ({walk_left, walk_right, aaah, digging} !== expected)
                $fatal(1, "Mismatch t=%0t activity=%0d direction=%0b inputs=%b got=%b expected=%b",
                    $time, activity, direction, {ground,dig,bump_left,bump_right},
                    {walk_left,walk_right,aaah,digging}, expected);
            checks = checks + 1;
        end
    endtask
    task reset_machine;
        begin
            @(negedge clk);
            #1 areset = 1;
            ground = 1; dig = 0; bump_left = 0; bump_right = 0;
            activity = 0;
            direction = 0;
            #1 check_outputs(); // asynchronous assertion, before clock edge
            @(posedge clk);
            #1 check_outputs();
            @(negedge clk);
            #1 areset = 0;
            #1 check_outputs();
        end
    endtask
    task step(input reg g, input reg d, input reg bl, input reg br);
        begin
            @(negedge clk);
            ground = g; dig = d; bump_left = bl; bump_right = br;
            #1 check_outputs(); // Moore outputs must hold before rising edge
            @(posedge clk);
            if (activity == 0) begin
                if (!g) activity = 1;
                else if (d) activity = 2;
                else if ((!direction && bl) || (direction && br))
                    direction = !direction;
            end else if (activity == 1) begin
                if (g) activity = 0;
            end else begin
                if (!g) activity = 1;
            end
            #1 check_outputs();
        end
    endtask
    task reach_state(input integer target);
        begin
            reset_machine();
            // target encoding: 2*activity + direction
            if ((target % 2) == 1) step(1,0,1,0);
            if ((target / 2) == 1) step(0,0,0,0);
            if ((target / 2) == 2) step(1,1,0,0);
        end
    endtask
    initial begin
        // All 16 input combinations from each reachable state.
        for (s = 0; s < 6; s = s + 1) begin
            for (v = 0; v < 16; v = v + 1) begin
                reach_state(s);
                step(v[3],v[2],v[1],v[0]);
                // Exercise persistence and landing after each transition.
                step(0,1,1,1);
                step(0,0,1,1);
                step(1,1,1,1);
                step(1,1,1,1);
                step(1,0,1,1);
            end
            reach_state(s);
            reset_machine();
        end
        // Long deterministic varied trace exercises retained direction.
        for (k = 0; k < 512; k = k + 1)
            step(((k % 11) > 2), ((k % 7) == 0), k[0], k[2]);
        $display("PASS: %0d output checks; exhaustive state/input transitions and asynchronous resets", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
