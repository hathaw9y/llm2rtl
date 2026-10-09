`timescale 1ns/1ps
module dev_tb;
    reg [3:0] in;
    wire [3:0] out_both, out_any, out_different;
    integer pattern, bit_index, digit, count;
    reg expected;
    TopModule dut (.in(in), .out_both(out_both), .out_any(out_any),
                   .out_different(out_different));

    task check_outputs;
        integer i;
        begin
            for (i = 0; i < 3; i = i + 1) begin
                expected = in[i] & in[i+1];
                if (out_both[i] !== expected)
                    $fatal(1, "out_both[%0d] input=%b got=%b expected=%b", i, in, out_both[i], expected);
            end
            for (i = 1; i < 4; i = i + 1) begin
                expected = in[i] | in[i-1];
                if (out_any[i] !== expected)
                    $fatal(1, "out_any[%0d] input=%b got=%b expected=%b", i, in, out_any[i], expected);
            end
            for (i = 0; i < 4; i = i + 1) begin
                expected = in[i] ^ in[(i+1)%4];
                if (out_different[i] !== expected)
                    $fatal(1, "out_different[%0d] input=%b got=%b expected=%b", i, in, out_different[i], expected);
            end
            count = count + 1;
        end
    endtask

    initial begin
        count = 0;
        for (pattern = 0; pattern < 16; pattern = pattern + 1) begin
            in = pattern;
            #1;
            check_outputs;
        end
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            digit = pattern;
            for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1) begin
                case (digit % 4)
                    0: in[bit_index] = 1'b0;
                    1: in[bit_index] = 1'b1;
                    2: in[bit_index] = 1'bx;
                    3: in[bit_index] = 1'bz;
                endcase
                digit = digit / 4;
            end
            #1;
            check_outputs;
        end
        $display("PASS: %0d combinational input cases", count);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
