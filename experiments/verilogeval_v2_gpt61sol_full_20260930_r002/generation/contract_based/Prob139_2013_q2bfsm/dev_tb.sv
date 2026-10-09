`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic resetn = 0;
    logic x = 0;
    logic y = 0;
    wire f, g;
    TopModule dut (.clk(clk), .resetn(resetn), .x(x), .y(y), .f(f), .g(g));
    always #5 clk = ~clk;

    // Behavioral oracle: startup age, raw sample history, and elapsed y samples.
    // No DUT state inspection or copied state transition table.
    integer startup_age = 0;
    integer x_samples = 0;
    logic [2:0] history = 0;
    integer y_samples = 0;
    bit detected = 0;
    bit decided = 0;
    bit expected_f = 0;
    bit expected_g = 0;
    integer checks = 0;
    integer pattern, cycle_index, trial;
    logic [31:0] random_bits = 32'h13579bdf;

    task automatic tick(input bit rn, input bit xv, input bit yv);
        bit old_f, old_g;
        begin
            @(negedge clk);
            old_f = expected_f;
            old_g = expected_g;
            resetn = rn;
            x = xv;
            y = yv;
            #1;
            if (checks > 0 && (f !== old_f || g !== old_g))
                $fatal(1, "Outputs changed between clock edges (synchronous contract)");
            @(posedge clk);
            if (!rn) begin
                startup_age = 0;
                x_samples = 0;
                history = 0;
                y_samples = 0;
                detected = 0;
                decided = 0;
                expected_f = 0;
                expected_g = 0;
            end else if (startup_age < 2) begin
                startup_age = startup_age + 1;
                expected_f = (startup_age == 1);
                expected_g = 0;
            end else if (!detected) begin
                history = {history[1:0], xv};
                x_samples = x_samples + 1;
                if (x_samples >= 3 && history == 3'b101) begin
                    detected = 1;
                    expected_g = 1;
                    y_samples = 0;
                end
            end else if (!decided) begin
                y_samples = y_samples + 1;
                if (yv) begin
                    expected_g = 1;
                    decided = 1;
                end else if (y_samples == 2) begin
                    expected_g = 0;
                    decided = 1;
                end
            end
            #1;
            checks = checks + 1;
            if (f !== expected_f || g !== expected_g)
                $fatal(1, "Mismatch check=%0d resetn=%b x=%b y=%b got f,g=%b%b expected=%b%b", checks, rn, xv, yv, f, g, expected_f, expected_g);
        end
    endtask

    task automatic start_and_detect;
        begin
            tick(0, 0, 0);
            tick(1, 1, 1); // f pulse: early x/y must have no effect
            tick(1, 0, 1); // enter monitoring
            tick(1, 1, 1);
            tick(1, 0, 1);
            tick(1, 1, 1); // detect 101: this y is outside the window
        end
    endtask

    initial begin
        tick(0, 1, 1);
        tick(0, 0, 0);
        start_and_detect();
        tick(1, 0, 0);
        tick(1, 0, 0);
        repeat (5) tick(1, 1, 1); // late y cannot rescue failed window
        start_and_detect();
        tick(1, 0, 1); // success on first eligible edge
        repeat (5) tick(1, 0, 0);
        start_and_detect();
        tick(1, 0, 0);
        tick(1, 0, 1); // success at exact two-cycle boundary
        repeat (5) tick(1, 1, 0);

        // Exhaustive 8-cycle x histories, crossed with all 4-cycle y histories.
        // Resets bound every trial; long suffix verifies persistent decisions.
        for (pattern = 0; pattern < 4096; pattern = pattern + 1) begin
            tick(0, 0, 0);
            tick(1, 1, 1);
            tick(1, 0, 0);
            for (cycle_index = 0; cycle_index < 12; cycle_index = cycle_index + 1)
                tick(1, (pattern >> (cycle_index % 8)) & 1,
                     (pattern >> (8 + cycle_index % 4)) & 1);
        end

        // Reset after every prefix of the path to both terminal outcomes.
        for (trial = 0; trial < 9; trial = trial + 1) begin
            tick(0, 0, 0);
            for (cycle_index = 0; cycle_index < trial; cycle_index = cycle_index + 1)
                tick(1, (cycle_index == 2 || cycle_index == 4), 0);
            tick(0, 1, 1);
            tick(1, 0, 0);
        end
        for (trial = 0; trial < 2000; trial = trial + 1) begin
            random_bits = {random_bits[30:0], random_bits[31] ^ random_bits[21] ^ random_bits[1] ^ random_bits[0]};
            tick((trial % 37 != 0), random_bits[0], random_bits[7]);
        end
        $display("PASS independent FSM checks=%0d", checks);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Timeout");
    end
endmodule
