`timescale 1ns/1ps
module dev_tb;
    logic [255:0] in;
    logic [7:0] sel;
    wire out;
    logic expected;
    logic [31:0] rng;
    integer checks = 0;
    integer bit_index, select_index, pattern_index, word_index;
    TopModule dut (.in(in), .sel(sel), .out(out));

    task automatic check_output;
        integer k;
        begin
            expected = 1'b0;
            for (k = 0; k < 256; k = k + 1)
                if (k == sel) expected = in[k];
            #1;
            if (out !== expected)
                $fatal(1, "FAIL sel=%0d expected=%b actual=%b", sel, expected, out);
            checks = checks + 1;
        end
    endtask

    task automatic sweep;
        integer s;
        begin
            for (s = 0; s < 256; s = s + 1) begin
                sel = s[7:0];
                check_output();
            end
        end
    endtask

    initial begin
        in = '0; sel = '0; sweep();
        in = '1; sweep();
        for (bit_index = 0; bit_index < 256; bit_index = bit_index + 1)
            in[bit_index] = (bit_index % 2) == 0;
        sweep();
        in = ~in; sweep();
        for (bit_index = 0; bit_index < 256; bit_index = bit_index + 1) begin
            in = '0; in[bit_index] = 1'b1; sweep();
            in = '1; in[bit_index] = 1'b0; sweep();
        end
        rng = 32'h19a7c053;
        for (pattern_index = 0; pattern_index < 32; pattern_index = pattern_index + 1) begin
            for (word_index = 0; word_index < 8; word_index = word_index + 1) begin
                rng = rng ^ (rng << 13);
                rng = rng ^ (rng >> 17);
                rng = rng ^ (rng << 5);
                in[word_index*32 +: 32] = rng;
            end
            sweep();
        end
        for (select_index = 0; select_index < 256; select_index = select_index + 1) begin
            sel = select_index[7:0];
            in = '0; check_output();
            in[select_index] = 1'b1; check_output();
            in[select_index] = 1'b0; check_output();
        end
        $display("PASS: %0d mux comparisons", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "FAIL: development simulation timeout");
    end
endmodule
