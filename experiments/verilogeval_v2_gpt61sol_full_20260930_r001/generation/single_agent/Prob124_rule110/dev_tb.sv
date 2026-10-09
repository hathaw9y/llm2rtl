`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [511:0] data = '0;
    wire [511:0] q;
    logic [511:0] expected;
    logic [511:0] next_expected;
    logic left_cell, right_cell;
    integer checks = 0;
    TopModule dut (.clk(clk), .load(load), .data(data), .q(q));
    always #5 clk = ~clk;

    task automatic step(input logic do_load, input logic [511:0] value);
        @(negedge clk);
        load = do_load;
        data = value;
        #1;
        if (checks != 0 && q !== expected)
            $fatal(1, "State changed before positive edge");
        if (do_load) begin
            next_expected = value;
        end else begin
            for (integer i = 0; i < 512; i = i + 1) begin
                left_cell = (i == 511) ? 1'b0 : expected[i+1];
                right_cell = (i == 0) ? 1'b0 : expected[i-1];
                case ({left_cell, expected[i], right_cell})
                    3'b110, 3'b101, 3'b011, 3'b010, 3'b001:
                        next_expected[i] = 1'b1;
                    default: next_expected[i] = 1'b0;
                endcase
            end
        end
        @(posedge clk);
        #1;
        expected = next_expected;
        if (q !== expected)
            $fatal(1, "Mismatch at check %0d", checks);
        checks = checks + 1;
    endtask

    logic [511:0] pattern;
    initial begin
        step(1, '0);
        step(0, '1);
        step(1, '1);
        repeat (20) step(0, '0);
        for (integer triplet = 0; triplet < 8; triplet = triplet + 1) begin
            pattern = '0;
            pattern[257:255] = triplet[2:0];
            step(1, pattern);
            step(0, '0);
        end
        pattern = '0;
        pattern[0] = 1'b1;
        pattern[511] = 1'b1;
        step(1, pattern);
        repeat (30) step(0, '0);
        for (integer n = 0; n < 200; n = n + 1) begin
            for (integer word_idx = 0; word_idx < 16; word_idx = word_idx + 1)
                pattern[word_idx*32 +: 32] = $urandom;
            step(1, pattern);
            repeat (5) step(0, '0);
        end
        $display("PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Development test timeout");
    end
endmodule
