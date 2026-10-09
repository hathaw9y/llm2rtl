`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg aresetn = 1;
    reg x = 0;
    wire z;
    reg [1:0] history = 0;
    integer samples = 0;
    integer checks = 0;
    integer pattern, bit_index;
    TopModule dut(.clk(clk), .aresetn(aresetn), .x(x), .z(z));

    // The oracle stores actual previously sampled bits, not FSM states.
    task check_output;
        reg expected;
        begin
            expected = (samples >= 2) && (history == 2'b10) && x;
            if (z !== expected)
                $fatal(1, "Mismatch at %0t: history=%b samples=%0d x=%b z=%b expected=%b",
                       $time, history, samples, x, z, expected);
            checks = checks + 1;
        end
    endtask

    task reset_now;
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

    task sample_bit(input reg value);
        begin
            clk = 0;
            x = value;
            #2;
            check_output(); // Mealy output before sampling current bit.
            clk = 1;
            history = {history[0], value};
            samples = samples + 1;
            #1;
            check_output(); // Updated state with current input still present.
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        reset_now();
        sample_bit(1); sample_bit(0); sample_bit(1);
        sample_bit(0); sample_bit(1); // Overlapping 10101.
        sample_bit(1); sample_bit(1); sample_bit(0);
        // Input changes without a clock must immediately affect detection.
        x = 1; #1; check_output();
        x = 0; #1; check_output();
        x = 1; #1; check_output();
        reset_now(); // Clear an active detection between clock edges.
        sample_bit(1); sample_bit(0);
        clk = 1; #1; // Already sampled zero; no additional posedge here.
        reset_now(); // Reset also works while clock is high.
        clk = 0;
        sample_bit(1);
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            reset_now();
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1)
                sample_bit((pattern >> bit_index) & 1);
        end
        $display("PASS: %0d checks, all eight-bit streams, overlap, Mealy timing and asynchronous reset", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
