module dev_tb;
    logic [1023:0] in;
    logic [7:0] sel;
    wire [3:0] out;
    integer pattern, index, bit_index;
    logic [1023:0] shifted;
    TopModule dut (.in(in), .sel(sel), .out(out));
    initial begin
        for (pattern = 0; pattern < 20; pattern = pattern + 1) begin
            for (bit_index = 0; bit_index < 1024; bit_index = bit_index + 1)
                in[bit_index] = $random;
            if (pattern == 0) in = '0;
            if (pattern == 1) in = '1;
            for (index = 0; index < 256; index = index + 1) begin
                sel = 8'(index);
                #1;
                shifted = in >> (index * 4);
                if (out !== shifted[3:0])
                    $fatal(1, "FAIL pattern=%0d sel=%0d", pattern, index);
            end
        end
        $display("PASS: 5120 mux comparisons across all 256 selections");
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL: timeout");
    end
endmodule
