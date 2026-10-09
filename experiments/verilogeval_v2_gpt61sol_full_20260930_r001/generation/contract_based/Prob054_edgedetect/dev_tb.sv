`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic [7:0] in;
    wire [7:0] pedge;
    logic [7:0] previous_sample;
    logic [7:0] expected;
    logic [7:0] held_output;
    integer checks = 0;
    integer a, b, bit_index;
    TopModule dut (.clk(clk), .in(in), .pedge(pedge));

    task automatic sample_and_check(input logic [7:0] value);
        begin
            held_output = pedge;
            in = value;
            #2;
            if (pedge !== held_output)
                $fatal(1, "Output changed before rising clock edge");
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                expected[bit_index] = (previous_sample[bit_index] == 1'b0) &&
                                      (value[bit_index] == 1'b1);
            clk = 1;
            #1;
            if (pedge !== expected)
                $fatal(1, "previous=%h current=%h expected=%h actual=%h", previous_sample, value, expected, pedge);
            previous_sample = value;
            checks = checks + 1;
            clk = 0;
            #1;
            if (pedge !== expected)
                $fatal(1, "Output changed on falling clock edge");
        end
    endtask

    initial begin
        in = 8'h00;
        #2;
        clk = 1;
        #1;
        previous_sample = 8'h00;
        clk = 0;
        #1;
        for (a = 0; a < 256; a = a + 1) begin
            for (b = 0; b < 256; b = b + 1) begin
                sample_and_check(a[7:0]);
                sample_and_check(b[7:0]);
            end
        end
        $display("PASS: %0d checked samples; all 65536 byte transition pairs; clock stability", checks);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Development testbench timeout");
    end
endmodule
