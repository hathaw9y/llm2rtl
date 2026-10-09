`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic resetn = 0;
    logic x = 0;
    logic y = 0;
    wire f, g;
    TopModule dut (.clk(clk), .resetn(resetn), .x(x), .y(y), .f(f), .g(g));
    always #5 clk = ~clk;

    integer startup = 0;
    integer samples = 0;
    integer budget = 0;
    integer checks = 0;
    integer high_decisions = 0;
    integer low_decisions = 0;
    integer patterns = 0;
    logic [2:0] history = 0;
    logic permanent = 0;
    logic expected_f = 0;
    logic expected_g = 0;
    logic initialized = 0;
    logic [31:0] rng = 32'h13579bdf;
    integer sequence_id, k;

    task automatic tick(input logic rn, input logic xx, input logic yy);
        begin
            @(negedge clk);
            resetn = rn;
            x = xx;
            y = yy;
            #1;
            // Input changes, including reset assertion, must not alter outputs
            // before a rising edge.
            if (initialized && ((f !== expected_f) || (g !== expected_g)))
                $fatal(1, "Output changed between clock edges at check %0d", checks);
            @(posedge clk);
            if (!rn) begin
                startup = 0;
                samples = 0;
                history = 0;
                budget = 0;
                permanent = 0;
                expected_f = 0;
                expected_g = 0;
                initialized = 1;
            end else if (startup == 0) begin
                expected_f = 1;
                startup = 1;
            end else if (startup == 1) begin
                expected_f = 0;
                startup = 2;
            end else if (!permanent) begin
                if (budget != 0) begin
                    if (yy) begin
                        permanent = 1;
                        expected_g = 1;
                        high_decisions = high_decisions + 1;
                    end else begin
                        budget = budget - 1;
                        if (budget == 0) begin
                            expected_g = 0;
                            permanent = 1;
                            low_decisions = low_decisions + 1;
                        end
                    end
                end else begin
                    history = {history[1:0], xx};
                    if (samples < 3) samples = samples + 1;
                    if ((samples == 3) && (history == 3'b101)) begin
                        expected_g = 1;
                        budget = 2;
                        patterns = patterns + 1;
                    end
                end
            end
            #1;
            checks = checks + 1;
            if ((f !== expected_f) || (g !== expected_g))
                $fatal(1, "Mismatch check=%0d resetn=%b x=%b y=%b expected=%b%b actual=%b%b", checks, rn, xx, yy, expected_f, expected_g, f, g);
        end
    endtask

    initial begin
        tick(0, 0, 0);
        // Every possible sequence of eight x/y pairs, with two more y=0
        // cycles to complete any pending decision, and late y=1 afterward.
        for (sequence_id = 0; sequence_id < 65536; sequence_id = sequence_id + 1) begin
            tick(0, 1, 1);
            tick(1, 1, 1);
            tick(1, 1, 1);
            for (k = 0; k < 8; k = k + 1)
                tick(1, (sequence_id >> (2*k)) & 1, (sequence_id >> (2*k+1)) & 1);
            tick(1, 0, 0);
            tick(1, 0, 0);
            tick(1, 1, 1);
            tick(1, 0, 1);
        end
        // Reset after each possible position in the startup/pattern/window
        // sequence, including both permanent outcomes.
        for (sequence_id = 0; sequence_id < 12; sequence_id = sequence_id + 1) begin
            tick(0, 0, 0);
            for (k = 0; k < sequence_id; k = k + 1)
                tick(1, (k == 2 || k == 4), 0);
            tick(0, 1, 1);
            tick(0, 1, 1);
            tick(1, 0, 0);
            tick(1, 0, 0);
            tick(1, 1, 0);
            tick(1, 0, 0);
            tick(1, 1, 0);
            tick(1, 0, 1);
            tick(1, 0, 0);
            tick(0, 1, 1);
        end
        // Fixed-seed random traffic with frequent synchronous reset.
        for (k = 0; k < 10000; k = k + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            tick(rng[7:4] != 0, rng[0], rng[1]);
        end
        if (patterns == 0 || high_decisions == 0 || low_decisions == 0)
            $fatal(1, "Missing decision coverage");
        $display("PASS checks=%0d patterns=%0d high_decisions=%0d low_decisions=%0d", checks, patterns, high_decisions, low_decisions);
        $finish;
    end

    initial begin
        #20000000;
        $fatal(1, "Testbench timeout");
    end
endmodule
