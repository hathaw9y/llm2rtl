`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg x = 0;
    wire z;
    integer checks = 0;
    integer n, value, k;
    reg [63:0] word_value, expected_word;
    reg carry_bit, inverted_bit, expected_bit;
    reg previous_z;
    TopModule dut (.clk(clk), .areset(areset), .x(x), .z(z));
    always #5 clk = ~clk;

    task check_output(input reg expected);
        begin
            if (z !== expected)
                $fatal(1, "Mismatch at %0t: z=%b expected=%b", $time, z, expected);
            checks = checks + 1;
        end
    endtask

    // Assert between edges and release between edges: reset is asynchronous.
    task reset_number;
        begin
            @(negedge clk);
            #1 areset = 1;
            #1 check_output(0);
            x = 1;
            @(posedge clk);
            #1 check_output(0);
            @(negedge clk);
            #1 x = 0;
            areset = 0;
            #1 check_output(0);
        end
    endtask

    task send_bit(input reg bit_value, input reg expected);
        begin
            @(negedge clk);
            previous_z = z;
            x = bit_value;
            #1 check_output(previous_z); // Moore output cannot follow x before clock.
            @(posedge clk);
            #1 check_output(expected);
        end
    endtask

    initial begin
        // Arithmetic oracle: all words through eight bits, serialized LSB first.
        for (n = 1; n <= 8; n = n + 1) begin
            for (value = 0; value < (1 << n); value = value + 1) begin
                reset_number;
                word_value = value;
                expected_word = (~word_value) + 64'd1;
                for (k = 0; k < n; k = k + 1)
                    send_bit(word_value[k], expected_word[k]);
            end
        end
        // Arbitrary length: binary addition of inverted input and one.
        // Long zero prefix, first one, then runs and alternating bits.
        reset_number;
        carry_bit = 1;
        for (k = 0; k < 1024; k = k + 1) begin
            if (k < 300) word_value[0] = 0;
            else if (k < 600) word_value[0] = 1;
            else word_value[0] = k % 2;
            inverted_bit = ~word_value[0];
            expected_bit = inverted_bit ^ carry_bit;
            carry_bit = inverted_bit & carry_bit;
            send_bit(word_value[0], expected_bit);
        end
        reset_number;
        send_bit(1, 1);
        // Reset interrupts an active conversion and starts a new number.
        reset_number;
        send_bit(0, 0);
        send_bit(1, 1);
        send_bit(0, 1);
        send_bit(1, 0);
        $display("PASS %0d checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
