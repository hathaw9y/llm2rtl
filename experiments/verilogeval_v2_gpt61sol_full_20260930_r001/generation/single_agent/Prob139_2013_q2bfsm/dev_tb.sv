`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic resetn = 0, x = 0, y = 0;
    wire f, g;
    TopModule dut (.clk(clk), .resetn(resetn), .x(x), .y(y), .f(f), .g(g));
    always #5 clk = ~clk;
    integer phase = 0, samples = 0, remaining = 0;
    logic [2:0] history = 0;
    logic expected_f = 0, expected_g = 0;
    integer checks = 0;
    integer sequence_id, cycle_id;

    task automatic tick(input logic rn, input logic xv, input logic yv);
        begin
            @(negedge clk);
            resetn = rn; x = xv; y = yv;
            @(posedge clk);
            if (!rn) begin
                phase = 0; samples = 0; history = 0; remaining = 0;
                expected_f = 0; expected_g = 0;
            end else begin
                case (phase)
                    0: begin phase = 1; expected_f = 1; end
                    1: begin phase = 2; expected_f = 0; end
                    2: begin
                        history = {history[1:0], xv};
                        if (samples < 3) samples = samples + 1;
                        if (samples == 3 && history == 3'b101) begin
                            phase = 3; remaining = 2; expected_g = 1;
                        end
                    end
                    3: begin
                        if (yv) phase = 4;
                        else begin
                            remaining = remaining - 1;
                            if (remaining == 0) begin phase = 5; expected_g = 0; end
                        end
                    end
                    4: expected_g = 1;
                    5: expected_g = 0;
                endcase
            end
            #1;
            checks = checks + 1;
            if (f !== expected_f || g !== expected_g)
                $fatal(1, "FAIL check=%0d phase=%0d x=%b y=%b got=%b%b expected=%b%b",
                       checks, phase, x, y, f, g, expected_f, expected_g);
        end
    endtask

    initial begin
        // Enumerate all paired x/y streams of eight search/window cycles.
        for (sequence_id = 0; sequence_id < 65536; sequence_id = sequence_id + 1) begin
            tick(0, 0, 0);
            tick(1, 1, 1);
            tick(1, 1, 1);
            for (cycle_id = 0; cycle_id < 8; cycle_id = cycle_id + 1)
                tick(1, (sequence_id >> (2*cycle_id)) & 1,
                        (sequence_id >> (2*cycle_id+1)) & 1);
            // Check permanent outcomes under changing inputs.
            repeat (3) begin tick(1, 1, 1); tick(1, 0, 0); end
        end
        // Random resets interrupt both monitoring and permanent states.
        repeat (10000) tick(($urandom_range(0, 15) != 0),
                             $urandom_range(0, 1), $urandom_range(0, 1));
        $display("PASS: %0d output comparisons", checks);
        $finish;
    end
    initial begin
        #20000000;
        $fatal(1, "FAIL: development simulation timeout");
    end
endmodule
