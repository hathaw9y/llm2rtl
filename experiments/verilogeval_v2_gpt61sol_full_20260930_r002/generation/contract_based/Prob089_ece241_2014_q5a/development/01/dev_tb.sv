`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic x = 0;
    wire z;
    integer checks = 0;
    integer width, value, bit_index;
    logic [63:0] word_value;
    TopModule dut (.clk(clk), .areset(areset), .x(x), .z(z));
    always #5 clk = ~clk;

    task automatic check_z(input logic expected);
        if (z !== expected)
            $fatal(1, "Mismatch at %0t: z=%b expected=%b", $time, z, expected);
        checks = checks + 1;
    endtask

    task automatic restart;
        @(negedge clk);
        #1 areset = 1;
        #1 check_z(0);
        x = ~x;
        #1 check_z(0);
        @(posedge clk);
        #1 check_z(0);
        @(negedge clk);
        #1 areset = 0;
        #1 check_z(0);
    endtask

    task automatic send_bit(input logic stimulus, input logic expected);
        logic held;
        @(negedge clk);
        held = z;
        x = stimulus;
        #1 check_z(held);
        @(posedge clk);
        #1 check_z(expected);
        x = ~stimulus;
        #1 check_z(expected);
    endtask

    task automatic run_word(input logic [63:0] bits, input integer count);
        logic [63:0] negated;
        integer i;
        begin
            // Arithmetic oracle is independent of the DUT state transitions.
            negated = (~bits) + 64'd1;
            restart();
            for (i = 0; i < count; i = i + 1)
                send_bit(bits[i], negated[i]);
        end
    endtask

    initial begin
        // Exhaustively verify every word of lengths 1 through 8.
        for (width = 1; width <= 8; width = width + 1)
            for (value = 0; value < (1 << width); value = value + 1)
                run_word(value, width);
        run_word(64'h0000000000000000, 64);
        run_word(64'h0000000000000001, 64);
        run_word(64'h8000000000000000, 64);
        run_word(64'hffffffffffffffff, 64);
        run_word(64'haaaaaaaaaaaaaaaa, 64);
        run_word(64'h5555555555555555, 64);
        word_value = 64'h3141592653589793;
        for (value = 0; value < 64; value = value + 1) begin
            word_value = {word_value[62:0], word_value[63] ^ word_value[62] ^ word_value[60] ^ word_value[59]};
            run_word(word_value, 64);
        end
        // 257-bit power of two: 128 initial zeros, one, then 128 zeros.
        // Its finite-width negation has the same initial zeros and all ones above.
        restart();
        for (bit_index = 0; bit_index < 257; bit_index = bit_index + 1)
            send_bit(bit_index == 128, bit_index >= 128);
        // Mid-conversion reset must discard the prior number.
        restart();
        send_bit(1, 1);
        send_bit(0, 1);
        restart();
        send_bit(0, 0);
        send_bit(0, 0);
        send_bit(1, 1);
        send_bit(1, 0);
        $display("PASS serial complement checks=%0d", checks);
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
