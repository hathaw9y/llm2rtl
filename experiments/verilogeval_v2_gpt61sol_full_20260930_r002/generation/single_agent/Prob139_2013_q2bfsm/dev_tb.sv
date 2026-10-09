`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic resetn = 0;
    logic x = 0, y = 0;
    wire f, g;
    TopModule dut (.clk(clk), .resetn(resetn), .x(x), .y(y), .f(f), .g(g));
    always #5 clk = ~clk;

    // Independent oracle: sample history and a bounded response timer.
    integer phase = 0;
    integer samples = 0;
    integer y_samples = 0;
    integer checks = 0;
    logic [2:0] history = 0;
    logic expected_f = 0, expected_g = 0;
    always @(posedge clk) begin
        if (!resetn) begin
            phase = 0;
            samples = 0;
            history = 0;
            y_samples = 0;
            expected_f = 0;
            expected_g = 0;
        end else begin
            case (phase)
                0: begin expected_f = 1; phase = 1; end
                1: begin expected_f = 0; phase = 2; end
                2: begin
                    history = {history[1:0], x};
                    if (samples < 3) samples = samples + 1;
                    if (samples >= 3 && history == 3'b101) begin
                        expected_g = 1;
                        y_samples = 0;
                        phase = 3;
                    end
                end
                3: begin
                    y_samples = y_samples + 1;
                    if (y) phase = 4;
                    else if (y_samples == 2) begin
                        expected_g = 0;
                        phase = 4;
                    end
                end
                4: begin end
                default: $fatal(1, "Oracle phase invalid");
            endcase
        end
        #1;
        checks = checks + 1;
        if (f !== expected_f || g !== expected_g)
            $fatal(1, "Mismatch check %0d: f=%b g=%b expected=%b,%b", checks, f, g, expected_f, expected_g);
    end

    task automatic step(input logic rn, input logic xx, input logic yy);
        @(negedge clk);
        resetn = rn; x = xx; y = yy;
        @(posedge clk); #2;
    endtask
    task automatic restart;
        step(0, 0, 0);
        step(0, 1, 1);
        step(1, 1, 1); // Pulse cycle: x and y must be ignored.
        step(1, 1, 1); // Enter monitoring phase.
    endtask
    integer pattern, response, bit_index;
    initial begin
        // Synchronous reset must leave outputs unchanged between edges.
        restart();
        @(negedge clk); resetn = 0;
        #1;
        if (f !== 0 || g !== 0) $fatal(1, "Unexpected between-edge output");
        @(posedge clk); #2;
        // Exhaust short x histories and all two-cycle y outcomes.
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            for (response = 0; response < 4; response = response + 1) begin
                restart();
                for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1)
                    step(1, (pattern >> bit_index) & 1, 0);
                // Ensure eventual detection for histories without 101.
                step(1, 1, 0);
                step(1, 0, 0);
                step(1, 1, 0);
                step(1, 0, response[0]);
                step(1, 1, response[1]);
                repeat (4) step(1, 1, 1);
            end
        end
        // Explicit fresh detection with y first, second, late, or never.
        for (response = 0; response < 4; response = response + 1) begin
            restart();
            step(1, 1, 1);
            step(1, 0, 1);
            step(1, 1, 1); // y here precedes the response window.
            step(1, 0, response[0]);
            step(1, 0, response[1]);
            repeat (8) step(1, 1, 1);
            step(0, 1, 1);
        end
        $display("PASS: %0d cycle checks", checks);
        $finish;
    end
    initial begin
        #250000;
        $fatal(1, "Timeout");
    end
endmodule
