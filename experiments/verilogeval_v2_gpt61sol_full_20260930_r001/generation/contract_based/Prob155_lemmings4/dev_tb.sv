`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic bump_left = 0, bump_right = 0, ground = 1, dig = 0;
    wire walk_left, walk_right, aaah, digging;
    TopModule dut(.*);
    always #5 clk = ~clk;

    integer mode = 0; // 0 walk, 1 dig, 2 fall, 3 dead
    integer age = 0;
    bit rightward = 0;
    integer checks = 0;
    logic [3:0] expected;
    logic [31:0] rng = 32'h73915abc;
    integer n, j, k;

    task automatic compare;
        begin
            expected = 4'b0000;
            case (mode)
                0: expected = rightward ? 4'b0100 : 4'b1000;
                1: expected = 4'b0001;
                2: expected = 4'b0010;
                3: expected = 4'b0000;
            endcase
            checks = checks + 1;
            if ({walk_left, walk_right, aaah, digging} !== expected)
                $fatal(1, "Mismatch check=%0d mode=%0d age=%0d expected=%b actual=%b", checks, mode, age, expected, {walk_left, walk_right, aaah, digging});
        end
    endtask

    task automatic reset_now;
        begin
            @(negedge clk);
            #2 areset = 1;
            mode = 0; age = 0; rightward = 0;
            #1 compare(); // check reset before next rising clock edge
            @(negedge clk);
            areset = 0;
        end
    endtask

    task automatic step(input bit g, input bit d, input bit bl, input bit br);
        begin
            @(negedge clk);
            ground = g; dig = d; bump_left = bl; bump_right = br;
            @(posedge clk);
            case (mode)
                0: begin
                    if (!g) begin mode = 2; age = 1; end
                    else if (d) mode = 1;
                    else if (rightward ? br : bl) rightward = !rightward;
                end
                1: if (!g) begin mode = 2; age = 1; end
                2: begin
                    if (g) begin
                        mode = (age > 20) ? 3 : 0;
                        age = 0;
                    end else age = age + 1;
                end
                3: mode = 3;
            endcase
            #1 compare();
        end
    endtask

    initial begin
        reset_now();
        // All walking input combinations in both directions.
        for (k = 0; k < 2; k = k + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                reset_now();
                if (k == 1) step(1,0,1,0);
                step(j[3],j[2],j[1],j[0]);
                step(1,0,0,0);
            end
        end
        // Exhaust fall lengths through both sides of threshold and beyond wrap range.
        for (n = 1; n <= 40; n = n + 1) begin
            for (k = 0; k < 2; k = k + 1) begin
                reset_now();
                if (k == 1) step(1,0,1,0);
                step(0,1,1,1);
                for (j = 1; j < n; j = j + 1) step(0, j[0], 1, 1);
                step(1,1,1,1); // landing ignores all other requests
                step(1,0,0,0);
            end
        end
        reset_now();
        step(1,0,1,0);
        step(1,1,1,1);
        repeat (5) step(1,0,1,1); // digging persists after dig deasserts
        step(0,1,1,1);
        repeat (99) step(0,1,1,1); // arbitrary long fall, no mid-air splatter
        step(1,1,1,1);
        repeat (20) step(0,1,1,1); // dead is absorbing
        reset_now();
        // Repeated short falls reset the elapsed duration.
        repeat (5) begin
            repeat (20) step(0,0,0,0);
            step(1,0,0,0);
        end
        step(1,1,0,0); reset_now(); // reset while digging
        step(0,0,0,0); reset_now(); // reset while falling
        for (j = 0; j < 3000; j = j + 1) begin
            rng = rng * 32'd1664525 + 32'd1013904223;
            if ((j % 71) == 0) reset_now();
            step(rng[31],rng[24],rng[16],rng[8]);
        end
        $display("PASS: %0d independent output checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1,"Development testbench timeout");
    end
endmodule
