`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg [7:0] in = 0;
    wire [7:0] anyedge;
    reg [7:0] last_sample;
    reg [7:0] last_output;
    reg [7:0] expected;
    integer a, b, bit_index;
    integer checked = 0;
    TopModule dut (.clk(clk), .in(in), .anyedge(anyedge));
    always #5 clk = ~clk;

    task sample_value(input [7:0] value);
        begin
            @(negedge clk);
            in = value;
            #1;
            if (anyedge !== last_output)
                $fatal(1, "Output changed between clock edges");
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                expected[bit_index] = (value[bit_index] != last_sample[bit_index]);
            @(posedge clk);
            #1;
            if (anyedge !== expected)
                $fatal(1, "Sample %0d: prior=%h input=%h expected=%h got=%h", checked, last_sample, value, expected, anyedge);
            last_sample = value;
            last_output = expected;
            checked = checked + 1;
        end
    endtask

    initial begin
        // No reset or initialization is specified. Prime the prior input
        // with one edge before checking fully defined outputs.
        @(posedge clk);
        #1;
        last_sample = 0;
        last_output = anyedge;
        sample_value(8'h00);
        sample_value(8'hff);
        sample_value(8'hff);
        sample_value(8'h00);
        sample_value(8'haa);
        sample_value(8'h55);
        for (a = 0; a < 8; a = a + 1) begin
            sample_value(8'h00);
            sample_value(8'h01 << a);
            sample_value(8'h00);
        end
        // A pulse entirely between sampling edges must not be captured.
        sample_value(8'h00);
        @(negedge clk);
        in = 8'hff;
        #1;
        if (anyedge !== 8'h00) $fatal(1, "Asynchronous edge detected");
        in = 8'h00;
        @(posedge clk);
        #1;
        if (anyedge !== 8'h00) $fatal(1, "Unsampled pulse detected");
        for (a = 0; a < 256; a = a + 1)
            for (b = 0; b < 256; b = b + 1) begin
                sample_value(a[7:0]);
                sample_value(b[7:0]);
            end
        $display("PASS: %0d sampled transitions checked", checked);
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1, "Timeout");
    end
endmodule
