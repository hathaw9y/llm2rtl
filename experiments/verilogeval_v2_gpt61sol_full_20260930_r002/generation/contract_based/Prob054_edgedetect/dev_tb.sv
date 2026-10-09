`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic [7:0] in = 8'h00;
    wire [7:0] pedge;
    logic [7:0] prior_sample;
    logic [7:0] held_output;
    logic [7:0] expected;
    bit primed = 0;
    integer checks = 0;
    integer a, b, i;

    TopModule dut (.clk(clk), .in(in), .pedge(pedge));
    always #5 clk = ~clk;

    task automatic sample(input logic [7:0] value);
        begin
            @(negedge clk);
            in = value;
            #1;
            if (primed && pedge !== held_output)
                $fatal(1, "Output changed between sampling edges");
            // Independent bit-wise oracle for the original 0-to-1 rule.
            for (integer bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                expected[bit_index] = (prior_sample[bit_index] == 1'b0)
                                      && (value[bit_index] == 1'b1);
            @(posedge clk);
            #1;
            if (primed) begin
                if (pedge !== expected)
                    $fatal(1, "sample %0d prior=%h current=%h expected=%h got=%h",
                           checks, prior_sample, value, expected, pedge);
                checks = checks + 1;
            end
            prior_sample = value;
            held_output = pedge;
            primed = 1;
        end
    endtask

    initial begin
        // First sampled cycle primes history; startup behavior is unspecified.
        sample(8'h00);
        sample(8'hff);
        sample(8'hff);
        sample(8'h00);
        sample(8'h00);
        for (i = 0; i < 8; i = i + 1) begin
            sample(8'h00);
            sample(8'b00000001 << i);
            sample(8'b00000001 << i);
        end
        // Exhaust every pair of consecutive known vector samples.
        for (a = 0; a < 256; a = a + 1)
            for (b = 0; b < 256; b = b + 1) begin
                sample(a[7:0]);
                sample(b[7:0]);
            end
        $display("PASS: %0d registered edge checks, including all byte pairs", checks);
        $finish;
    end

    initial begin
        #2000000;
        $fatal(1, "Timeout");
    end
endmodule
