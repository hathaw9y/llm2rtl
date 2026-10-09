`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg bump_left = 0;
    reg bump_right = 0;
    wire walk_left, walk_right;
    reg expected_right;
    integer checks = 0;
    integer direction, pattern, repeat_index;

    TopModule dut(.clk(clk), .areset(areset), .bump_left(bump_left),
                  .bump_right(bump_right), .walk_left(walk_left),
                  .walk_right(walk_right));

    task check_outputs;
        begin
            if ({walk_left, walk_right} !== {~expected_right, expected_right})
                $fatal(1, "Mismatch at %0t: expected direction right=%b, outputs=%b%b",
                       $time, expected_right, walk_left, walk_right);
            checks = checks + 1;
        end
    endtask

    task tick;
        input left_bump;
        input right_bump;
        begin
            clk = 0;
            bump_left = left_bump;
            bump_right = right_bump;
            #2;
            check_outputs(); // Inputs alone must not change Moore outputs.
            if (areset)
                expected_right = 0;
            else begin
                case ({left_bump, right_bump})
                    2'b00: expected_right = expected_right;
                    2'b10: expected_right = 1;
                    2'b01: expected_right = 0;
                    2'b11: expected_right = ~expected_right;
                endcase
            end
            clk = 1;
            #1;
            check_outputs();
            clk = 0;
            #1;
            check_outputs();
        end
    endtask

    task reset_between_edges;
        begin
            clk = 0;
            #2;
            areset = 1;
            expected_right = 0;
            #1;
            check_outputs();
            #2;
            areset = 0;
            #1;
            check_outputs();
        end
    endtask

    initial begin
        // The original gives no known power-up direction before reset.
        reset_between_edges();
        for (direction = 0; direction < 2; direction = direction + 1) begin
            for (pattern = 0; pattern < 4; pattern = pattern + 1) begin
                reset_between_edges();
                if (direction == 1) tick(1, 0);
                tick((pattern >> 1) & 1, pattern & 1);
            end
        end
        for (repeat_index = 0; repeat_index < 12; repeat_index = repeat_index + 1)
            tick(1, 1);
        tick(1, 0);
        for (repeat_index = 0; repeat_index < 4; repeat_index = repeat_index + 1)
            tick(1, 0);
        tick(0, 1);
        for (repeat_index = 0; repeat_index < 4; repeat_index = repeat_index + 1)
            tick(0, 1);
        tick(1, 0);
        reset_between_edges(); // Reset immediately changes a right-walking machine.
        areset = 1;
        #1;
        expected_right = 0;
        check_outputs();
        tick(1, 1); // Reset dominates both bumps on the clock edge.
        tick(1, 0);
        areset = 0;
        #1;
        check_outputs(); // Release itself causes no transition.
        tick(1, 0);
        tick(0, 0);
        $display("PASS: %0d Lemmings development checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
