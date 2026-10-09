`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg bump_left = 0, bump_right = 0, ground = 1, dig = 0;
    wire walk_left, walk_right, aaah, digging;
    TopModule dut(.*);
    always #5 clk = ~clk;

    // Behavioral oracle: activity 0=walking, 1=falling, 2=digging.
    integer activity = 0;
    reg direction_right = 0;
    integer checks = 0;
    integer s, v, k;
    reg [3:0] stimulus;

    task check_outputs;
        reg [3:0] expected;
        begin
            expected = {activity == 0 && !direction_right,
                        activity == 0 && direction_right,
                        activity == 1, activity == 2};
            if ({walk_left,walk_right,aaah,digging} !== expected)
                $fatal(1,"Mismatch at %0t activity=%0d right=%0b expected=%b actual=%b",
                       $time,activity,direction_right,expected,
                       {walk_left,walk_right,aaah,digging});
            checks = checks + 1;
        end
    endtask

    task reset_machine;
        begin
            @(negedge clk);
            #1 areset = 1;
            ground = 1; dig = 0; bump_left = 0; bump_right = 0;
            activity = 0;
            direction_right = 0;
            #1 check_outputs(); // asynchronous assertion between clock edges
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
            #1 check_outputs(); // Moore outputs do not respond to new inputs
            @(posedge clk);
            case (activity)
                0: begin
                    if (!g) activity = 1;
                    else if (d) activity = 2;
                    else if ((!direction_right && bl) || (direction_right && br))
                        direction_right = !direction_right;
                end
                1: if (g) activity = 0;
                2: if (!g) activity = 1;
            endcase
            #1 check_outputs();
        end
    endtask

    initial begin
        // Establish each of the six observable activity/direction combinations
        // from reset, then exhaustively apply all input combinations.
        for (s = 0; s < 6; s = s + 1) begin
            for (v = 0; v < 16; v = v + 1) begin
                reset_machine();
                if (s % 2) step(1,0,1,0);
                if (s / 2 == 1) step(0,0,0,0);
                if (s / 2 == 2) step(1,1,0,0);
                stimulus = v;
                step(stimulus[3],stimulus[2],stimulus[1],stimulus[0]);
                // Follow through release/landing with both bumps and dig asserted.
                step(0,1,1,1);
                step(1,1,1,1);
                step(1,0,0,0);
            end
        end
        reset_machine();
        for (k = 0; k < 1000; k = k + 1) begin
            stimulus = $random;
            step(stimulus[3],stimulus[2],stimulus[1],stimulus[0]);
            if (k % 79 == 0) reset_machine();
        end
        // Reset directly from digging and falling, including right direction.
        reset_machine();
        step(1,0,1,0);
        step(1,1,1,1);
        reset_machine();
        step(1,0,1,0);
        step(0,1,1,1);
        reset_machine();
        $display("PASS: %0d output checks",checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1,"Test timeout");
    end
endmodule
