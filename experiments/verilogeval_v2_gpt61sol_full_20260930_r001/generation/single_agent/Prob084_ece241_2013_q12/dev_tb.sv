`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic enable = 0;
    logic S = 0;
    logic A = 0, B = 0, C = 0;
    wire Z;
    logic expected [0:7];
    integer word_value, bit_index, address, k;
    integer comparisons = 0;
    TopModule dut (.clk(clk), .enable(enable), .S(S), .A(A), .B(B), .C(C), .Z(Z));

    task check_all;
        begin
            for (address = 0; address < 8; address = address + 1) begin
                {A,B,C} = address[2:0];
                #1;
                if (Z !== expected[address])
                    $fatal(1, "Mismatch address=%0d expected=%b actual=%b", address, expected[address], Z);
                comparisons = comparisons + 1;
            end
        end
    endtask

    task step(input logic shift_enable, input logic serial_bit);
        begin
            clk = 0;
            enable = shift_enable;
            S = serial_bit;
            #1;
            clk = 1;
            if (shift_enable) begin
                for (k = 7; k > 0; k = k - 1)
                    expected[k] = expected[k-1];
                expected[0] = serial_bit;
            end
            #1;
            check_all();
            clk = 0;
            #1;
            check_all();
        end
    endtask

    initial begin
        for (k = 0; k < 8; k = k + 1) expected[k] = 1'bx;
        for (word_value = 0; word_value < 256; word_value = word_value + 1) begin
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
                step(1'b1, ((word_value >> bit_index) & 1));
                step(1'b0, !S);
            end
            for (address = 0; address < 8; address = address + 1) begin
                {A,B,C} = address[2:0];
                #1;
                if (Z !== ((word_value >> address) & 1'b1))
                    $fatal(1, "Loaded word mismatch word=%0d address=%0d", word_value, address);
                comparisons = comparisons + 1;
            end
        end
        $display("PASS: %0d comparisons, all 256 words, shifting, enable hold, and asynchronous reads", comparisons);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Testbench timeout");
    end
endmodule
