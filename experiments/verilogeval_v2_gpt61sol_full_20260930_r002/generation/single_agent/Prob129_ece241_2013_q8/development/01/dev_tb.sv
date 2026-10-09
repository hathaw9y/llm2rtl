`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic aresetn = 1;
    logic x = 0;
    wire z;
    logic [1:0] history = 0;
    integer samples = 0;
    integer checks = 0;
    integer stream, bit_index;
    TopModule dut (.clk(clk), .aresetn(aresetn), .x(x), .z(z));

    task automatic check_output;
        logic expected;
        begin
            expected = (samples >= 2) && (history == 2'b10) && x;
            if (z !== expected)
                $fatal(1, "Mismatch time=%0t history=%b samples=%0d x=%b z=%b expected=%b",
                       $time, history, samples, x, z, expected);
            checks = checks + 1;
        end
    endtask

    task automatic reset_now;
        begin
            aresetn = 0;
            history = 0;
            samples = 0;
            #1;
            check_output();
            aresetn = 1;
            #1;
            check_output();
        end
    endtask

    task automatic sample_bit(input logic value);
        begin
            x = value;
            #1;
            check_output(); // Mealy detection before the accepting edge.
            clk = 1;
            history = {history[0], value};
            samples = samples + 1;
            #1;
            check_output(); // Recompute from newly sampled history.
            clk = 0;
            #1;
        end
    endtask

    initial begin
        #1;
        reset_now();
        // All eight-bit streams include runs, misses, and overlapping 10101.
        for (stream = 0; stream < 256; stream = stream + 1) begin
            reset_now();
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1)
                sample_bit((stream >> bit_index) & 1);
        end
        reset_now();
        sample_bit(1);
        sample_bit(0);
        // Changes without clock edges must immediately affect Mealy output.
        x = 1; #1; check_output();
        x = 0; #1; check_output();
        x = 1; #1; check_output();
        // Reset while detection is asserted and clock remains low.
        reset_now();
        sample_bit(1);
        sample_bit(0);
        x = 1; #1; check_output();
        // Reset also operates while clock remains high, without a new edge.
        clk = 1;
        history = {history[0], x}; samples = samples + 1;
        #1; check_output();
        reset_now();
        clk = 0;
        sample_bit(0);
        sample_bit(1);
        sample_bit(0);
        sample_bit(1);
        sample_bit(0);
        sample_bit(1);
        $display("PASS: %0d independent history checks", checks);
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
