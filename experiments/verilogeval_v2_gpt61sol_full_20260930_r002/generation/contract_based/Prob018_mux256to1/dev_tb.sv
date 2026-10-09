`timescale 1ns/1ps
module dev_tb;
    logic [255:0] in;
    logic [7:0] sel;
    wire out;
    integer checks = 0;
    integer bit_index;
    integer select_index;
    integer pattern_index;
    logic expected;

    TopModule dut (.in(in), .sel(sel), .out(out));

    // Independently decode the original mapping by matching an integer index.
    task automatic check_output;
        integer k;
        logic oracle;
        begin
            oracle = 1'bx;
            for (k = 0; k < 256; k = k + 1)
                if (sel == k) oracle = in[k];
            #1;
            if (out !== oracle)
                $fatal(1, "Mismatch: sel=%0d expected=%b actual=%b", sel, oracle, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        #200000;
        $fatal(1, "Timeout");
    end

    initial begin
        in = '0;
        sel = 8'd0;
        for (pattern_index = 0; pattern_index < 4; pattern_index = pattern_index + 1) begin
            for (bit_index = 0; bit_index < 256; bit_index = bit_index + 1) begin
                case (pattern_index)
                    0: in[bit_index] = 1'b0;
                    1: in[bit_index] = 1'b1;
                    2: in[bit_index] = (bit_index % 2 == 0);
                    3: in[bit_index] = (bit_index % 2 != 0);
                endcase
            end
            for (select_index = 0; select_index < 256; select_index = select_index + 1) begin
                sel = select_index;
                check_output();
            end
        end
        // Every single-bit position is tested against every selector.
        for (bit_index = 0; bit_index < 256; bit_index = bit_index + 1) begin
            in = '0;
            in[bit_index] = 1'b1;
            for (select_index = 0; select_index < 256; select_index = select_index + 1) begin
                sel = select_index;
                expected = (select_index == bit_index);
                #1;
                if (out !== expected)
                    $fatal(1, "Walking-one mismatch: bit=%0d sel=%0d", bit_index, select_index);
                checks = checks + 1;
            end
            in = '1;
            in[bit_index] = 1'b0;
            for (select_index = 0; select_index < 256; select_index = select_index + 1) begin
                sel = select_index;
                expected = (select_index != bit_index);
                #1;
                if (out !== expected)
                    $fatal(1, "Walking-zero mismatch: bit=%0d sel=%0d", bit_index, select_index);
                checks = checks + 1;
            end
        end
        // Fixed selector, changing selected and unselected input values.
        for (select_index = 0; select_index < 256; select_index = select_index + 1) begin
            sel = select_index;
            in = '0;
            check_output();
            in[select_index] = 1'b1;
            check_output();
            in = '1;
            check_output();
            in[select_index] = 1'b0;
            check_output();
            in[select_index] = 1'bx;
            check_output();
            in[select_index] = 1'bz;
            check_output();
        end
        $display("PASS mux256to1 checks=%0d", checks);
        $finish;
    end
endmodule
