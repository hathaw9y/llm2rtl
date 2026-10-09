`timescale 1ns/1ps
module dev_tb;
    logic [3:0] in;
    wire [3:0] out_both, out_any, out_different;
    integer value;
    integer bit_index;
    logic expected;

    TopModule dut (.in(in), .out_both(out_both),
                   .out_any(out_any), .out_different(out_different));

    initial begin
        #100;
        $fatal(1, "Timeout");
    end

    initial begin
        for (value = 0; value < 16; value = value + 1) begin
            in = value[3:0];
            #1;
            for (bit_index = 0; bit_index < 3; bit_index = bit_index + 1) begin
                expected = (in[bit_index] == 1'b1) &&
                           (in[bit_index+1] == 1'b1);
                if (out_both[bit_index] !== expected)
                    $fatal(1, "out_both mismatch input=%b bit=%0d", in, bit_index);
            end
            for (bit_index = 1; bit_index < 4; bit_index = bit_index + 1) begin
                expected = (in[bit_index] == 1'b1) ||
                           (in[bit_index-1] == 1'b1);
                if (out_any[bit_index] !== expected)
                    $fatal(1, "out_any mismatch input=%b bit=%0d", in, bit_index);
            end
            for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1) begin
                expected = (in[bit_index] != in[(bit_index+1)%4]);
                if (out_different[bit_index] !== expected)
                    $fatal(1, "out_different mismatch input=%b bit=%0d", in, bit_index);
            end
        end
        $display("PASS exhaustive 16-input neighbour checks");
        $finish;
    end
endmodule
