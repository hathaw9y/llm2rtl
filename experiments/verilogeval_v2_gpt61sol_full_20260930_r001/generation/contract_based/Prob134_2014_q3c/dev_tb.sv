`timescale 1ns/1ps
module dev_tb;
    logic clk, x;
    logic [2:0] y;
    wire Y0, z;
    integer checks = 0;
    integer pass_index, state_index, input_index, clock_index;
    TopModule dut (.clk(clk), .x(x), .y(y), .Y0(Y0), .z(z));

    task automatic check(input logic [2:0] state_value,
                         input logic input_value,
                         input logic clock_value);
        logic [1:0] expected;
        begin
            // Explicit {Y0,z} values derived from the original problem table.
            case ({state_value, input_value})
                4'b0000: expected = 2'b00;
                4'b0001: expected = 2'b10;
                4'b0010: expected = 2'b10;
                4'b0011: expected = 2'b00;
                4'b0100: expected = 2'b00;
                4'b0101: expected = 2'b10;
                4'b0110: expected = 2'b11;
                4'b0111: expected = 2'b01;
                4'b1000: expected = 2'b11;
                4'b1001: expected = 2'b01;
                default: expected = 2'b00;
            endcase
            clk = clock_value;
            x = input_value;
            y = state_value;
            #1;
            if ({Y0,z} !== expected)
                $fatal(1, "FAIL y=%b x=%b clk=%b actual=%b expected=%b",
                       y, x, clk, {Y0,z}, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        clk = 0; x = 0; y = 0;
        for (pass_index = 0; pass_index < 2; pass_index = pass_index + 1)
            for (clock_index = 0; clock_index < 2; clock_index = clock_index + 1)
                for (state_index = 0; state_index < 8; state_index = state_index + 1)
                    for (input_index = 0; input_index < 2; input_index = input_index + 1)
                        check(pass_index == 0 ? 3'(state_index) : 3'(7-state_index),
                              1'(input_index), 1'(clock_index));
        $display("PASS: %0d comparisons including all table rows, clock independence, repeated changes, and default states", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL: development test timeout");
    end
endmodule
