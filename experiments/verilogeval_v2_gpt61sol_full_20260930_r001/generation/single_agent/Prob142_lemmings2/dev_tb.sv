`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic bump_left = 0, bump_right = 0, ground = 1;
    wire walk_left, walk_right, aaah;
    bit direction_right = 0, falling = 0;
    integer checks = 0;
    integer state_index, input_index, i;
    TopModule dut (.*);
    always #5 clk = ~clk;

    task automatic check_outputs;
        logic [2:0] expected;
        begin
            expected = {(!falling && !direction_right),
                        (!falling && direction_right), falling};
            if ({walk_left, walk_right, aaah} !== expected)
                $fatal(1, "Mismatch: expected %b actual %b", expected,
                       {walk_left, walk_right, aaah});
            checks = checks + 1;
        end
    endtask

    task automatic reset_dut;
        begin
            @(negedge clk);
            #1 areset = 1;
            direction_right = 0;
            falling = 0;
            #1 check_outputs();
            #1 areset = 0;
        end
    endtask

    task automatic step(input bit g, input bit bl, input bit br);
        begin
            @(negedge clk);
            ground = g;
            bump_left = bl;
            bump_right = br;
            #1 check_outputs(); // Moore outputs cannot respond to input changes.
            @(posedge clk);
            if (falling) begin
                if (g) falling = 0;
            end else if (!g) begin
                falling = 1;
            end else if ((!direction_right && bl) || (direction_right && br)) begin
                direction_right = !direction_right;
            end
            #1 check_outputs();
        end
    endtask

    initial begin
        // Exercise all eight input combinations from each of the four states.
        for (state_index = 0; state_index < 4; state_index = state_index + 1) begin
            for (input_index = 0; input_index < 8; input_index = input_index + 1) begin
                reset_dut();
                if (state_index == 1 || state_index == 3) step(1, 1, 0);
                if (state_index >= 2) step(0, 1, 1);
                step(input_index[2], input_index[1], input_index[0]);
            end
        end
        // Long deterministic input sequence with resets during arbitrary activity.
        for (i = 0; i < 1024; i = i + 1) begin
            if ((i % 71) == 0) reset_dut();
            step(((i*13 + i/7) % 5) != 0,
                 ((i*7 + i/3) % 3) == 0,
                 ((i*11 + i/5) % 4) == 0);
        end
        $display("PASS: %0d output checks, all state/input transitions and asynchronous resets", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Development test timeout");
    end
endmodule
