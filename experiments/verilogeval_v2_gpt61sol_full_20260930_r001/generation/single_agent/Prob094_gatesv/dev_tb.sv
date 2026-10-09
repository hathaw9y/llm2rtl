module dev_tb;
    logic [3:0] in;
    wire [3:0] out_both, out_any, out_different;
    TopModule dut (.in(in), .out_both(out_both), .out_any(out_any), .out_different(out_different));
    initial begin
        for (int value = 0; value < 16; value++) begin
            in = 4'(value);
            #1;
            for (int bit_index = 0; bit_index < 3; bit_index++) begin
                if (out_both[bit_index] !== (in[bit_index] & in[bit_index+1]))
                    $fatal(1, "out_both mismatch input=%b bit=%0d", in, bit_index);
            end
            for (int bit_index = 1; bit_index < 4; bit_index++) begin
                if (out_any[bit_index] !== (in[bit_index] | in[bit_index-1]))
                    $fatal(1, "out_any mismatch input=%b bit=%0d", in, bit_index);
            end
            for (int bit_index = 0; bit_index < 4; bit_index++) begin
                if (out_different[bit_index] !== (in[bit_index] ^ in[(bit_index+1)%4]))
                    $fatal(1, "out_different mismatch input=%b bit=%0d", in, bit_index);
            end
        end
        $display("PASS: all 16 inputs checked");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Testbench timeout");
    end
endmodule
