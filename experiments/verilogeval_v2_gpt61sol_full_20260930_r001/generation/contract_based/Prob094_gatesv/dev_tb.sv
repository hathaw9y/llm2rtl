`timescale 1ns/1ps
module dev_tb;
    logic [3:0] in;
    wire [3:0] out_both, out_any, out_different;
    integer pattern, direction, bit_index, left_index;
    logic expected;
    TopModule dut (.in(in), .out_both(out_both),
                   .out_any(out_any), .out_different(out_different));
    initial begin
        for (direction = 0; direction < 2; direction = direction + 1) begin
            for (pattern = 0; pattern < 16; pattern = pattern + 1) begin
                if (direction == 0) in = 4'(pattern);
                else in = 4'(15 - pattern);
                #1;
                for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1) begin
                    if (bit_index < 3) begin
                        expected = (in[bit_index] == 1'b1) && (in[bit_index+1] == 1'b1);
                        if (out_both[bit_index] !== expected)
                            $fatal(1, "out_both mismatch input=%b bit=%0d", in, bit_index);
                    end
                    if (bit_index > 0) begin
                        expected = (in[bit_index] == 1'b1) || (in[bit_index-1] == 1'b1);
                        if (out_any[bit_index] !== expected)
                            $fatal(1, "out_any mismatch input=%b bit=%0d", in, bit_index);
                    end
                    left_index = (bit_index + 1) % 4;
                    expected = (in[bit_index] != in[left_index]);
                    if (out_different[bit_index] !== expected)
                        $fatal(1, "out_different mismatch input=%b bit=%0d", in, bit_index);
                end
                if (out_both[3] !== 1'b0 || out_any[0] !== 1'b0)
                    $fatal(1, "Boundary tie-off mismatch");
            end
        end
        $display("PASS: all 16 binary inputs checked in both directions (32 cases)");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Testbench timeout");
    end
endmodule
