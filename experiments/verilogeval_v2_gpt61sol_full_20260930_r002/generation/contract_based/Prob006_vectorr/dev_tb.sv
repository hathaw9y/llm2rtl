`timescale 1ns/1ps
module dev_tb;
    logic [7:0] in;
    wire [7:0] out;
    logic [7:0] stimulus;
    integer checks = 0;
    TopModule dut (.in(in), .out(out));

    task automatic check_reverse(input logic [7:0] value);
        logic [7:0] expected;
        begin
            for (integer bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                expected[bit_index] = value[7-bit_index];
            in = value;
            #1;
            if (out !== expected)
                $fatal(1, "Reverse mismatch: in=%b out=%b expected=%b", in, out, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        // No reset or clock exists in the original interface.
        check_reverse(8'bxxxxxxxx);
        for (integer value = 0; value < 256; value = value + 1)
            check_reverse(value[7:0]);
        for (integer position = 0; position < 8; position = position + 1) begin
            stimulus = 8'hA5;
            stimulus[position] = 1'bx;
            check_reverse(stimulus);
            stimulus = 8'h5A;
            stimulus[position] = 1'bz;
            check_reverse(stimulus);
        end
        check_reverse(8'bzzzzzzzz);
        $display("PASS bit reversal: %0d checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
