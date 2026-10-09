`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic x = 0;
    wire z;
    bit seen_one = 0;
    integer checks = 0;
    integer pattern, bit_index;
    TopModule dut (.clk(clk), .areset(areset), .x(x), .z(z));

    // Independent behavioral oracle: after the first sampled 1,
    // invert every subsequent input until asynchronous reset.
    always @(posedge clk or posedge areset) begin
        if (areset) seen_one = 0;
        else if (x) seen_one = 1;
    end

    task automatic check_output;
        logic expected;
        begin
            expected = seen_one ? ~x : x;
            if (z !== expected)
                $fatal(1, "Mismatch t=%0t clk=%b reset=%b x=%b seen=%b expected=%b actual=%b",
                       $time, clk, areset, x, seen_one, expected, z);
            checks = checks + 1;
        end
    endtask

    task automatic reset_now;
        begin
            areset = 1;
            #1; check_output();
            areset = 0;
            #1; check_output();
        end
    endtask

    task automatic sample_bit(input bit value);
        begin
            x = value;
            #1; check_output(); // Mealy output before the sampling edge
            clk = 1;
            #1; check_output(); // State transition has settled
            x = ~value;
            #1; check_output(); // Output must respond without a clock edge
            x = value;
            #1; check_output();
            clk = 0;
            #1; check_output(); // Falling edge cannot change state
        end
    endtask

    initial begin
        #1;
        reset_now();
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            reset_now();
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                sample_bit((pattern >> bit_index) & 1);
        end
        // Asynchronous reset in B, with x=1, between rising edges.
        reset_now();
        sample_bit(1);
        x = 1;
        #1; check_output();
        reset_now();
        // Remain in A across rising edges while reset is held high.
        areset = 1;
        #1; check_output();
        sample_bit(1);
        sample_bit(0);
        x = 1;
        #1; check_output();
        areset = 0;
        #1; check_output();
        sample_bit(1);
        sample_bit(0);
        $display("PASS: %0d output checks, exhaustive 8-bit streams and asynchronous reset", checks);
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
