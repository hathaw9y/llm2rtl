`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic in = 0;
    wire out;
    integer model;
    integer checks = 0;
    integer coverage [0:3][0:1];
    integer reset_coverage [0:3];
    integer seq_idx, bit_idx, s, b;
    TopModule dut (.clk(clk), .areset(areset), .in(in), .out(out));
    always #5 clk = ~clk;

    // Independent table oracle: A=0, B=1, C=2, D=3.
    function automatic integer transition(input integer current, input bit value);
        case (current)
            0: if (value) transition = 1; else transition = 0;
            1: if (value) transition = 1; else transition = 2;
            2: if (value) transition = 3; else transition = 0;
            3: if (value) transition = 1; else transition = 2;
            default: $fatal(1, "Invalid oracle state");
        endcase
    endfunction

    task automatic check_output;
        begin
            if (out !== (model == 3))
                $fatal(1, "Output mismatch at %0t: model=%0d out=%b", $time, model, out);
            checks = checks + 1;
        end
    endtask

    task automatic reset_fsm;
        begin
            @(negedge clk);
            #2;
            reset_coverage[model] = reset_coverage[model] + 1;
            areset = 1;
            model = 0;
            #1; check_output(); // No clock edge: asynchronous assertion.
            @(posedge clk);
            #1; check_output(); // Reset held through a rising clock edge.
            areset = 0;
            #1; check_output(); // Deassertion alone does not change state.
        end
    endtask

    task automatic step(input bit value);
        begin
            @(negedge clk);
            in = value;
            #1; check_output(); // Moore output must ignore input changes.
            coverage[model][value] = coverage[model][value] + 1;
            @(posedge clk);
            model = transition(model, value);
            #1; check_output(); // Observe after nonblocking assignments settle.
        end
    endtask

    initial begin
        #100000;
        $fatal(1, "Timeout");
    end

    initial begin
        // No output expectation before the first reset: initial state unspecified.
        model = 0;
        for (s = 0; s < 4; s = s + 1) begin
            reset_coverage[s] = 0;
            for (b = 0; b < 2; b = b + 1) coverage[s][b] = 0;
        end
        reset_fsm();
        for (seq_idx = 0; seq_idx < 256; seq_idx = seq_idx + 1) begin
            reset_fsm();
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1)
                step((seq_idx >> bit_idx) & 1);
        end
        // Explicit reset from each reachable state, including output-high D.
        for (s = 0; s < 4; s = s + 1) begin
            reset_fsm();
            if (s >= 1) step(1);
            if (s >= 2) step(0);
            if (s >= 3) step(1);
            reset_fsm();
        end
        for (s = 0; s < 4; s = s + 1) begin
            if (reset_coverage[s] == 0) $fatal(1, "Missing reset state %0d", s);
            for (b = 0; b < 2; b = b + 1)
                if (coverage[s][b] == 0) $fatal(1, "Missing transition %0d/%0d", s, b);
        end
        $display("PASS: %0d checks, all transitions and resets covered", checks);
        $finish;
    end
endmodule
