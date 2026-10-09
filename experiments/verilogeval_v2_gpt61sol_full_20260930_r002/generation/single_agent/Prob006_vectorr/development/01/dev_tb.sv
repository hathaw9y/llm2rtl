`timescale 1ns/1ps
module dev_tb;
    logic [7:0] in;
    wire [7:0] out;
    integer value;
    integer checks = 0;
    TopModule dut (.in(in), .out(out));

    task automatic check_reverse(input logic [7:0] stimulus);
        integer bit_index;
        begin
            in = stimulus;
            #1;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                if (out[bit_index] !== stimulus[7-bit_index])
                    $fatal(1, "Bit reversal mismatch: in=%b out=%b bit=%0d", in, out, bit_index);
            end
            checks = checks + 1;
        end
    endtask

    initial begin
        for (value = 0; value < 256; value = value + 1)
            check_reverse(value[7:0]);
        check_reverse(8'bx01z10xz);
        check_reverse(8'bzzzzzzzz);
        check_reverse(8'bxxxxxxxx);
        check_reverse(8'b10000000);
        check_reverse(8'b00000001);
        $display("PASS: %0d bit reversal cases", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Testbench timeout");
    end
endmodule
