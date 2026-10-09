`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 1;
    wire [31:0] q;
    logic [31:0] expected = 32'h1;
    logic [31:0] next_expected;
    integer cycle;
    integer bit_index;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    initial begin
        #1;
        for (cycle = 0; cycle < 4096; cycle = cycle + 1) begin
            @(posedge clk);
            if (reset) begin
                expected = 32'h1;
            end else begin
                for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1) begin
                    if (bit_index == 31)
                        next_expected[bit_index] = expected[0];
                    else if (bit_index == 21 || bit_index == 1 || bit_index == 0)
                        next_expected[bit_index] = expected[bit_index+1] ^ expected[0];
                    else
                        next_expected[bit_index] = expected[bit_index+1];
                end
                expected = next_expected;
            end
            #1;
            if (q !== expected)
                $fatal(1, "FAIL cycle=%0d expected=%h actual=%h", cycle, expected, q);
            if (cycle == 1 && q !== 32'h8020_0003)
                $fatal(1, "FAIL first feedback transition");
            @(negedge clk);
            #1;
            reset = (cycle == 100 || cycle == 101 || cycle == 2000);
            #1;
            if (q !== expected)
                $fatal(1, "FAIL output changed between clock edges");
        end
        $display("PASS: 4096 cycles, feedback transitions, repeated synchronous resets, and edge stability");
        $finish;
    end
    initial begin
        #50000;
        $fatal(1, "FAIL simulation timeout");
    end
endmodule
