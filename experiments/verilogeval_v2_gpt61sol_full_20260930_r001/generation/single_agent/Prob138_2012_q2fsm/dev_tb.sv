`timescale 1ns/1ps
module dev_tb;
    logic clk = 0, reset = 0, w = 0;
    wire z;
    integer model = 0;
    integer checks = 0;
    integer seq, step;
    integer coverage [0:5][0:1];
    TopModule dut (.clk(clk), .reset(reset), .w(w), .z(z));
    always #5 clk = ~clk;

    function automatic integer advance(input integer s, input bit b);
        case (s)
            0: advance = b ? 1 : 0;
            1: advance = b ? 2 : 3;
            2: advance = b ? 4 : 3;
            3: advance = b ? 5 : 0;
            4: advance = b ? 4 : 3;
            5: advance = b ? 2 : 3;
            default: advance = 0;
        endcase
    endfunction

    task automatic cycle(input bit rst, input bit b);
        bit expected_before;
        begin
            @(negedge clk);
            expected_before = (model == 4 || model == 5);
            reset = rst;
            w = b;
            #1;
            if (z !== expected_before)
                $fatal(1, "Output changed before rising edge");
            @(posedge clk);
            if (rst) model = 0;
            else begin
                coverage[model][b] = coverage[model][b] + 1;
                model = advance(model, b);
            end
            #1;
            if (z !== (model == 4 || model == 5))
                $fatal(1, "Output mismatch: model=%0d z=%b", model, z);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (integer s = 0; s < 6; s = s + 1)
            for (integer b = 0; b < 2; b = b + 1)
                coverage[s][b] = 0;
        reset = 1;
        @(posedge clk);
        #1;
        if (z !== 0) $fatal(1, "Initial reset failed");
        // Exhaust all length-eight input sequences, resetting between sequences.
        for (seq = 0; seq < 256; seq = seq + 1) begin
            cycle(1, seq[0]);
            for (step = 0; step < 8; step = step + 1)
                cycle(0, (seq >> step) & 1);
        end
        // Reset while output is high, including consecutive reset cycles.
        cycle(1, 0);
        cycle(0, 1); cycle(0, 1); cycle(0, 1);
        cycle(1, 1); cycle(1, 0);
        for (integer s = 0; s < 6; s = s + 1)
            for (integer b = 0; b < 2; b = b + 1)
                if (coverage[s][b] == 0)
                    $fatal(1, "Uncovered transition %0d/%0d", s, b);
        $display("PASS: %0d checked cycles; all 12 transitions covered", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Testbench timeout");
    end
endmodule
