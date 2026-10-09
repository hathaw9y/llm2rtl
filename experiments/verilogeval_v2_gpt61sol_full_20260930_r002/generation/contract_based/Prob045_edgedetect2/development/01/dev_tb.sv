`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic [7:0] in = 8'h00;
    wire [7:0] anyedge;
    logic [7:0] previous_sample = 8'hxx;
    logic [7:0] expected;
    logic [7:0] held_output;
    integer checks = 0;
    integer a, b, bit_index;

    TopModule dut (.clk(clk), .in(in), .anyedge(anyedge));
    always #5 clk = ~clk;

    // Oracle derives each output bit from whether two consecutive samples differ.
    task automatic sample_and_check(input logic [7:0] value);
        integer k;
        begin
            @(negedge clk);
            held_output = anyedge;
            in = value;
            #1;
            if (anyedge !== held_output)
                $fatal(1, "Output changed before rising edge");
            for (k = 0; k < 8; k = k + 1) begin
                if ((value[k] === 1'bx) || (value[k] === 1'bz) ||
                    (previous_sample[k] === 1'bx) || (previous_sample[k] === 1'bz))
                    expected[k] = 1'bx;
                else if (value[k] == previous_sample[k])
                    expected[k] = 1'b0;
                else
                    expected[k] = 1'b1;
            end
            @(posedge clk);
            #1;
            if (anyedge !== expected)
                $fatal(1, "Sample %0d input=%h prior=%h expected=%h actual=%h",
                       checks, value, previous_sample, expected, anyedge);
            previous_sample = value;
            checks = checks + 1;
        end
    endtask

    initial begin
        #1;
        if (anyedge !== 8'hxx) $fatal(1, "Unexpected initialized output");
        // First edge establishes history; no prior sample is available.
        @(posedge clk);
        #1;
        if (anyedge !== 8'hxx) $fatal(1, "First comparison should lack history");
        previous_sample = 8'h00;
        sample_and_check(8'h00);
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            sample_and_check(8'h01 << bit_index);
            sample_and_check(8'h01 << bit_index);
            sample_and_check(8'h00);
        end
        sample_and_check(8'hff);
        sample_and_check(8'h00);
        sample_and_check(8'haa);
        sample_and_check(8'h55);
        // A pulse entirely between sampling edges must not be detected.
        sample_and_check(8'h00);
        @(negedge clk);
        held_output = anyedge;
        in = 8'hff;
        #1;
        if (anyedge !== held_output) $fatal(1, "Detected unsampled pulse");
        in = 8'h00;
        @(posedge clk);
        #1;
        if (anyedge !== 8'h00) $fatal(1, "Unsampled pulse affected output");
        previous_sample = 8'h00;
        // Exhaust all ordered known sample pairs, including unchanged values.
        for (a = 0; a < 256; a = a + 1)
            for (b = 0; b < 256; b = b + 1) begin
                sample_and_check(a[7:0]);
                sample_and_check(b[7:0]);
            end
        sample_and_check(8'b01x10z01);
        sample_and_check(8'h00);
        sample_and_check(8'h00);
        $display("PASS: %0d sampled comparisons and hold checks", checks);
        $finish;
    end

    initial begin
        #2000000;
        $fatal(1, "Timeout");
    end
endmodule
