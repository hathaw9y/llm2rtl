`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic j = 0;
    logic k = 0;
    wire out;
    logic expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .j(j), .k(k), .out(out));

    task automatic check_output;
        begin
            if (out !== expected)
                $fatal(1, "Mismatch: expected=%b actual=%b reset=%b j=%b k=%b", expected, out, reset, j, k);
            checks = checks + 1;
        end
    endtask

    task automatic step(input logic r, input logic a, input logic b);
        begin
            clk = 0;
            reset = r; j = a; k = b;
            #2;
            check_output();
            if (r) expected = 0;
            else begin
                case ({expected, a, b})
                    3'b000, 3'b001: expected = 0;
                    3'b010, 3'b011: expected = 1;
                    3'b100, 3'b110: expected = 1;
                    3'b101, 3'b111: expected = 0;
                endcase
            end
            clk = 1;
            #2;
            check_output();
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        // Establish state without assuming a power-up value.
        reset = 1;
        #2; clk = 1;
        #2; expected = 0; check_output();
        clk = 0;
        for (integer state_index = 0; state_index < 2; state_index = state_index + 1) begin
            for (integer inputs = 0; inputs < 4; inputs = inputs + 1) begin
                step(1, 0, 0);
                if (state_index == 1) step(0, 1, 0);
                step(0, inputs[1], inputs[0]);
                step(1, 0, 0);
                if (state_index == 1) step(0, 1, 0);
                step(1, inputs[1], inputs[0]);
                step(1, inputs[1], inputs[0]);
            end
        end
        // Consecutive both-high inputs alternate OFF and ON.
        for (integer n = 0; n < 16; n = n + 1) step(0, 1, 1);
        // Deterministic varied sequences exercise state-dependent input relevance.
        for (integer n = 0; n < 64; n = n + 1)
            step((n % 13) == 0, ((n * 7) % 5) < 2, ((n * 3) % 7) < 3);
        $display("PASS: %0d output checks", checks);
        $finish;
    end
    initial begin
        #5000;
        $fatal(1, "Testbench timeout");
    end
endmodule
