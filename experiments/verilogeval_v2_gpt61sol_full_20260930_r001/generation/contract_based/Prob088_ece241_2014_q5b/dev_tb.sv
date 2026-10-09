`timescale 1ns/1ps
module dev_tb;
    logic clk = 0, areset = 0, x = 0;
    wire z;
    bit seen_one = 0;
    integer word_value, bit_index, negated, checks = 0;
    TopModule dut (.clk(clk), .areset(areset), .x(x), .z(z));

    task automatic check_output;
        begin
            if (z !== (x ^ seen_one))
                $fatal(1, "Output mismatch x=%b seen=%b z=%b", x, seen_one, z);
            if (dut.state_r !== (seen_one ? 2'b10 : 2'b01))
                $fatal(1, "One-hot state mismatch: %b", dut.state_r);
            checks = checks + 1;
        end
    endtask

    task automatic reset_dut;
        begin
            clk = 0;
            #2; areset = 1; seen_one = 0;
            #1; check_output();
            x = 1;
            #1; check_output();
            clk = 1;
            #1; check_output();
            clk = 0; x = 0;
            #1; check_output();
            areset = 0;
            #1; check_output();
        end
    endtask

    initial begin
        for (word_value = 0; word_value < 256; word_value = word_value + 1) begin
            reset_dut();
            negated = (-word_value) & 255;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                x = (word_value >> bit_index) & 1;
                #1; check_output();
                if (z !== ((negated >> bit_index) & 1))
                    $fatal(1, "Serial arithmetic mismatch word=%d bit=%d", word_value, bit_index);
                clk = 1;
                seen_one = seen_one | x;
                #1; check_output();
                clk = 0;
                // Exercise immediate combinational response without a clock.
                x = ~x;
                #1; check_output();
                x = ~x;
                #1; check_output();
            end
        end
        // Explicit asynchronous reset from B while input is high.
        x = 1; clk = 1; seen_one = 1;
        #1; check_output();
        clk = 0;
        #2; areset = 1; seen_one = 0;
        #1; check_output();
        areset = 0;
        #1; check_output();
        $display("PASS: exhaustive 256 serial words and reset/Mealy checks; %0d comparisons", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Development simulation timeout");
    end
endmodule
