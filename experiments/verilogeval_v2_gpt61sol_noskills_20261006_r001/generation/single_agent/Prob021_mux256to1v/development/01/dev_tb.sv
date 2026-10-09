`timescale 1ns/1ps
module dev_tb;
    reg [1023:0] in;
    reg [7:0] sel;
    wire [3:0] out;
    integer i, j, p, bit_index;
    reg [3:0] expected;
    TopModule dut (.in(in), .sel(sel), .out(out));

    // Oracle reads each bit independently from the specified packed order.
    task check;
        begin
            #1;
            for (integer b = 0; b < 4; b = b + 1)
                expected[b] = in[4 * integer'(sel) + b];
            if (out !== expected)
                $fatal(1, "sel=%0d expected=%b got=%b", sel, expected, out);
        end
    endtask

    initial begin
        in = 0;
        sel = 0;
        check();
        for (p = 0; p < 16; p = p + 1) begin
            for (j = 0; j < 256; j = j + 1)
                for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1)
                    in[j * 4 + bit_index] = ((j + p) >> bit_index) & 1;
            for (i = 0; i < 256; i = i + 1) begin
                sel = i;
                check();
            end
        end
        // Isolate every input bit, testing its selected word and neighbors.
        for (j = 0; j < 1024; j = j + 1) begin
            in = 0;
            in[j] = 1;
            sel = j / 4;
            check();
            sel = (j / 4 + 1) % 256;
            check();
        end
        // Four-state data must propagate only from the selected word.
        in = {1024{1'bx}};
        in[3:0] = 4'b1010;
        sel = 0;
        check();
        sel = 255;
        check();
        in[1023:1020] = 4'bz01x;
        check();
        $display("PASS: all mux selections, data values, boundaries, and four-state data");
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
