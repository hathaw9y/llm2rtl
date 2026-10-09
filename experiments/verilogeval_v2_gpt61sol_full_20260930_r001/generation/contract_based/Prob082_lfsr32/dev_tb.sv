`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 1;
    wire [31:0] q;
    logic [31:0] expected;
    logic [31:0] held;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    function automatic [31:0] advance(input logic [31:0] state);
        integer bit_index;
        begin
            advance[31] = state[0];
            for (bit_index = 0; bit_index < 31; bit_index = bit_index + 1) begin
                advance[bit_index] = state[bit_index+1];
                if (bit_index == 21 || bit_index == 1 || bit_index == 0)
                    advance[bit_index] = advance[bit_index] ^ state[0];
            end
        end
    endfunction

    task automatic check(input logic [31:0] value);
        begin
            if (q !== value)
                $fatal(1, "FAIL check %0d expected=%08h actual=%08h", checks, value, q);
            checks = checks + 1;
        end
    endtask

    initial begin
        expected = 32'h1;
        repeat (3) begin
            @(posedge clk); #1; check(expected);
        end
        @(negedge clk); reset = 0;
        @(posedge clk); #1;
        expected = advance(expected);
        check(32'h80200003);
        check(expected);
        repeat (4096) begin
            @(negedge clk); held = q;
            #1; check(held);
            @(posedge clk); #1;
            expected = advance(expected);
            check(expected);
        end
        @(negedge clk); held = q;
        #1; reset = 1;
        #1; check(held);
        @(posedge clk); #1;
        expected = 32'h1; check(expected);
        @(negedge clk); reset = 0;
        repeat (64) begin
            @(posedge clk); #1;
            expected = advance(expected); check(expected);
        end
        $display("PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
