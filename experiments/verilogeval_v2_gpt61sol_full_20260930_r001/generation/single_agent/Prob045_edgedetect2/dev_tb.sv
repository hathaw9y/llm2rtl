`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic [7:0] in = 8'h00;
    wire [7:0] anyedge;
    logic [7:0] previous_sample;
    logic [7:0] expected;
    logic [7:0] held_output;
    integer checks = 0;
    integer a, b;
    TopModule dut (.clk(clk), .in(in), .anyedge(anyedge));
    always #5 clk = ~clk;

    task automatic sample(input logic [7:0] value);
        @(negedge clk);
        held_output = anyedge;
        in = value;
        expected = previous_sample ^ value;
        #1;
        if (anyedge !== held_output) $fatal(1, "Output changed between clock edges");
        @(posedge clk);
        #1;
        if (anyedge !== expected)
            $fatal(1, "Mismatch previous=%h current=%h expected=%h actual=%h", previous_sample, value, expected, anyedge);
        previous_sample = value;
        checks = checks + 1;
        #1;
        if (anyedge !== expected) $fatal(1, "Output not stable");
    endtask

    initial begin
        @(posedge clk);
        #1;
        previous_sample = 8'h00;
        sample(8'h00);
        sample(8'hff);
        sample(8'hff);
        sample(8'h00);
        sample(8'haa);
        sample(8'h55);
        for (a = 0; a < 256; a = a + 1) begin
            for (b = 0; b < 256; b = b + 1) begin
                sample(8'(a));
                sample(8'(b));
            end
        end
        $display("PASS: %0d sampled transitions", checks);
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1, "Development test timeout");
    end
endmodule
