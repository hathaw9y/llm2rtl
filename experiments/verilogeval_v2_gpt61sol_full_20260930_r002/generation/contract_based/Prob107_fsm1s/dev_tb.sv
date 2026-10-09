`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic in = 0;
    wire out;
    integer expected_state;
    bit model_valid = 0;
    integer checks = 0;
    integer idx;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .out(out));

    task automatic check_output;
        if (model_valid) begin
            checks = checks + 1;
            if (out !== (expected_state == 1))
                $fatal(1, "Mismatch t=%0t expected=%0d actual=%b reset=%b in=%b", $time, expected_state, out, reset, in);
        end
    endtask

    // Manual clocking checks both sampling boundaries and stability.
    task automatic cycle(input bit rst_value, input bit input_value);
        reset = rst_value;
        in = input_value;
        #2;
        check_output();
        clk = 1;
        if (reset) begin
            expected_state = 1; // B, from original reset statement
            model_valid = 1;
        end else if (model_valid) begin
            case (expected_state)
                0: begin
                    if (in == 0) expected_state = 1; // A -> B
                    else expected_state = 0;        // A -> A
                end
                1: begin
                    if (in == 0) expected_state = 0; // B -> A
                    else expected_state = 1;        // B -> B
                end
            endcase
        end
        #1;
        check_output();
        #2;
        clk = 0;
        #1;
        check_output();
    endtask

    initial begin
        // Pre-reset output is unspecified and is deliberately not scored.
        #1;
        cycle(1, 0);
        cycle(0, 1); // B holds
        cycle(0, 0); // B -> A
        cycle(0, 1); // A holds
        cycle(0, 0); // A -> B
        cycle(0, 0); // B -> A

        // Assert reset in A away from an edge: must not reset asynchronously.
        reset = 1;
        #1;
        check_output();
        reset = 0; // pulse entirely between rising edges must have no effect
        #1;
        check_output();
        cycle(0, 1);
        cycle(1, 1);
        cycle(1, 0);
        cycle(1, 1);
        cycle(0, 0);
        cycle(1, 0); // reset in A beats toggling
        cycle(0, 1);

        // Input mutation without a clock must not affect Moore output.
        in = 0;
        #1;
        check_output();
        in = 1;
        #1;
        check_output();
        for (idx = 0; idx < 128; idx = idx + 1)
            cycle((idx % 19) == 7, ((idx * 13 + idx / 3) % 7) < 3);
        $display("PASS checked %0d output samples", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
