`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg [7:0] in = 0;
    wire [7:0] anyedge;
    reg [7:0] last_sample;
    reg [7:0] expected;
    reg [7:0] held;
    reg [31:0] rng = 32'h81c3a597;
    integer checks = 0;
    integer k;
    TopModule dut (.clk(clk), .in(in), .anyedge(anyedge));

    task sample(input reg [7:0] value);
        integer bit_index;
        begin
            // No rising edge occurs while input is driven; output must hold.
            held = anyedge;
            in = value;
            #2;
            if (anyedge !== held) $fatal(1, "Output changed between clock edges");
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                if (value[bit_index] == last_sample[bit_index])
                    expected[bit_index] = 0;
                else if (value[bit_index] != last_sample[bit_index])
                    expected[bit_index] = 1;
                else
                    expected[bit_index] = 1'bx;
            end
            clk = 1;
            #1;
            if (anyedge !== expected)
                $fatal(1, "Sample %0d: old=%h current=%h expected=%h actual=%h", checks, last_sample, value, expected, anyedge);
            last_sample = value;
            checks = checks + 1;
            clk = 0;
            #1;
            if (anyedge !== expected) $fatal(1, "Falling edge changed output");
        end
    endtask

    initial begin
        #1;
        if (anyedge !== 8'hxx) $fatal(1, "Unexpected initialized output");
        sample(8'h00); // First sample has no known predecessor.
        sample(8'h00);
        sample(8'hff);
        sample(8'hff);
        sample(8'h00);
        for (k = 0; k < 8; k = k + 1) begin
            sample(8'b1 << k);
            sample(8'b1 << k);
            sample(8'h00);
        end
        sample(8'haa);
        sample(8'h55);
        sample(8'haa);
        // A pulse entirely between sampling edges must not be detected.
        held = anyedge;
        in = 8'h55;
        #1;
        if (anyedge !== held) $fatal(1, "Asynchronous pulse affected output");
        in = 8'haa;
        sample(8'haa);
        sample(8'h0f);
        sample(8'hf0);
        for (k = 0; k < 256; k = k + 1) begin
            rng = (rng << 1) ^ (rng[31] ? 32'h04c11db7 : 32'h00000000);
            sample(rng[7:0]);
            if (k % 16 == 0) sample(rng[7:0]);
        end
        $display("PASS: %0d sampled comparisons and output hold checks", checks);
        $finish;
    end
    initial begin
        #5000;
        $fatal(1, "Timeout");
    end
endmodule
