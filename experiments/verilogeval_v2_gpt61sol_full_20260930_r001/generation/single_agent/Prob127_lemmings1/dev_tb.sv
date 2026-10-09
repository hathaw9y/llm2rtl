`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic bump_left = 0, bump_right = 0;
    wire walk_left, walk_right;
    logic expected_right = 0;
    integer checks = 0;
    TopModule dut (.*);
    always #5 clk = ~clk;

    task automatic check_output;
        begin
            if ({walk_left, walk_right} !== {~expected_right, expected_right})
                $fatal(1, "FAIL: expected right=%b, outputs=%b%b", expected_right, walk_left, walk_right);
            checks = checks + 1;
        end
    endtask

    task automatic reset_left;
        begin
            @(negedge clk);
            #2 areset = 1;
            expected_right = 0;
            #1 check_output(); // Reset must take effect before a clock edge.
            @(posedge clk);
            #1 check_output();
            @(negedge clk);
            areset = 0;
        end
    endtask

    task automatic step(input logic left_bump, input logic right_bump);
        begin
            @(negedge clk);
            bump_left = left_bump;
            bump_right = right_bump;
            #1 check_output(); // Moore outputs cannot respond directly to bumps.
            @(posedge clk);
            if (expected_right ? right_bump : left_bump)
                expected_right = ~expected_right;
            #1 check_output();
        end
    endtask

    initial begin
        // Exercise every bump combination from both states independently.
        for (integer direction = 0; direction < 2; direction = direction + 1) begin
            for (integer bumps = 0; bumps < 4; bumps = bumps + 1) begin
                reset_left();
                if (direction == 1) step(1, 0);
                step((bumps & 2) != 0, (bumps & 1) != 0);
            end
        end
        reset_left();
        repeat (8) step(1, 1);
        step(1, 0);
        reset_left(); // Reset while walking right.
        step(0, 0);
        $display("PASS: %0d output checks", checks);
        $finish;
    end
    initial begin
        #5000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
