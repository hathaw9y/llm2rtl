`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic [7:0] in = 8'h00;
    wire [7:0] anyedge;
    logic [7:0] previous_sample;
    logic [7:0] expected;
    logic [7:0] held;
    bit have_previous = 0;
    integer checks = 0;
    integer a, b, k;

    TopModule dut (.clk(clk), .in(in), .anyedge(anyedge));

    task automatic sample(input logic [7:0] value);
        begin
            in = value;
            #2;
            if (have_previous && anyedge !== held)
                $fatal(1, "Output changed between clock edges");
            clk = 1'b1;
            for (integer i = 0; i < 8; i = i + 1)
                expected[i] = (value[i] != previous_sample[i]);
            #1;
            if (have_previous) begin
                if (anyedge !== expected)
                    $fatal(1, "Mismatch previous=%h current=%h got=%h expected=%h", previous_sample, value, anyedge, expected);
                checks = checks + 1;
            end
            previous_sample = value;
            have_previous = 1;
            held = anyedge;
            clk = 1'b0;
            #1;
        end
    endtask

    initial begin
        sample(8'h00);
        sample(8'h00);
        sample(8'hff);
        sample(8'hff);
        sample(8'h00);
        for (k = 0; k < 8; k = k + 1) begin
            sample(8'b1 << k);
            sample(8'h00);
        end
        sample(8'haa);
        sample(8'h55);
        sample(8'haa);
        // An input pulse entirely between sampling edges must not affect output.
        in = 8'hff;
        #1;
        if (anyedge !== held) $fatal(1, "Asynchronous output change");
        in = previous_sample;
        #1;
        sample(previous_sample);
        for (a = 0; a < 256; a = a + 1)
            for (b = 0; b < 256; b = b + 1) begin
                sample(a[7:0]);
                sample(b[7:0]);
            end
        $display("PASS: %0d sampled comparisons, all 65536 input pairs covered", checks);
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "Testbench timeout");
    end
endmodule
