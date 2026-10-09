`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d, e;
    wire [24:0] out;
    logic [4:0] inputs_bits;
    logic [24:0] expected;
    integer vector_index, row_index, col_index;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .e(e), .out(out));
    initial begin
        for (vector_index = 0; vector_index < 32; vector_index = vector_index + 1) begin
            inputs_bits = vector_index[4:0];
            {a,b,c,d,e} = inputs_bits;
            for (row_index = 0; row_index < 5; row_index = row_index + 1)
                for (col_index = 0; col_index < 5; col_index = col_index + 1)
                    expected[24-5*row_index-col_index] =
                        (inputs_bits[4-row_index] == inputs_bits[4-col_index]);
            #1;
            if (out !== expected)
                $fatal(1, "FAIL vector=%b expected=%b actual=%b", inputs_bits, expected, out);
        end
        $display("PASS: all 32 binary inputs, 800 output-bit comparisons");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
