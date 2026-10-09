`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic in = 0;
    wire out;
    integer expected_state = 0;
    integer checks = 0;
    integer transitions [0:3][0:1];
    integer word_idx, bit_idx, s, b;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .out(out));
    always #5 clk = ~clk;

    task automatic step(input logic rst, input logic value);
        logic old_out;
        begin
            @(negedge clk);
            old_out = out;
            reset = rst;
            in = value;
            #1;
            if (out !== old_out) $fatal(1, "Output changed between clock edges");
            @(posedge clk);
            if (rst) expected_state = 0;
            else begin
                transitions[expected_state][value]++;
                case (expected_state)
                    0: if (value) expected_state = 1; else expected_state = 0;
                    1: if (value) expected_state = 1; else expected_state = 2;
                    2: if (value) expected_state = 3; else expected_state = 0;
                    3: if (value) expected_state = 1; else expected_state = 2;
                endcase
            end
            #1;
            checks++;
            if (out !== (expected_state == 3))
                $fatal(1, "Mismatch at check %0d state %0d out %b", checks, expected_state, out);
        end
    endtask

    initial begin
        for (s = 0; s < 4; s++)
            for (b = 0; b < 2; b++) transitions[s][b] = 0;
        step(1, 0);
        for (word_idx = 0; word_idx < 256; word_idx++) begin
            step(1, 1);
            for (bit_idx = 0; bit_idx < 8; bit_idx++)
                step(0, ((word_idx >> bit_idx) & 1));
        end
        // Assert reset while the Moore output is high, then hold reset.
        step(1, 0);
        step(0, 1);
        step(0, 0);
        step(0, 1);
        step(1, 1);
        step(1, 0);
        step(0, 0);
        for (s = 0; s < 4; s++)
            for (b = 0; b < 2; b++)
                if (transitions[s][b] == 0) $fatal(1, "Uncovered transition");
        $display("PASS: %0d output checks; all eight transitions covered; synchronous reset checked", checks);
        $finish;
    end
    initial begin
        #50000;
        $fatal(1, "Testbench timeout");
    end
endmodule
