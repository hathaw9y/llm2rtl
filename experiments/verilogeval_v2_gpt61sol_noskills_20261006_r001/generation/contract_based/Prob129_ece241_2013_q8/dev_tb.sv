`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg aresetn = 1;
    reg x = 0;
    wire z;
    reg [1:0] history = 0;
    integer checks = 0;
    integer pattern, bit_index;
    TopModule dut(.clk(clk), .aresetn(aresetn), .x(x), .z(z));

    task check_output;
        reg expected;
        begin
            expected = (history == 2'b10) && x;
            if (z !== expected)
                $fatal(1, "Mealy mismatch time=%0t history=%b x=%b reset=%b expected=%b z=%b", $time, history, x, aresetn, expected, z);
            checks = checks + 1;
        end
    endtask

    task reset_async;
        begin
            // Called away from a rising clock edge, including from matching prefixes.
            #1; aresetn = 0; history = 0;
            #1; check_output;
            x = ~x;
            #1; check_output;
            clk = 1;
            #1; check_output;
            clk = 0;
            #1; aresetn = 1;
            #1; check_output;
        end
    endtask

    task sample_bit(input reg value);
        begin
            x = value;
            #1; check_output; // Current input can assert z before the edge.
            clk = 1;
            history = {history[0], value};
            #1; check_output; // State has consumed current input.
            x = ~value;
            #1; check_output; // Changing x without a clock must change Mealy output.
            x = value;
            #1; check_output;
            clk = 0;
            #1; check_output;
        end
    endtask

    initial begin
        // Original does not specify power-up values, so establish reset first.
        reset_async;
        sample_bit(1); sample_bit(0); sample_bit(1);
        sample_bit(0); sample_bit(1); // Overlapping 10101.
        reset_async;
        sample_bit(1); reset_async; // Reset from prefix 1.
        sample_bit(1); sample_bit(0);
        x = 1; #1; check_output;
        reset_async; // Reset while z is asserted for prefix 10 plus current 1.
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            reset_async;
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1)
                sample_bit((pattern >> bit_index) & 1);
        end
        $display("PASS: %0d checks, all eight-bit streams, overlap, Mealy phases and asynchronous reset", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
