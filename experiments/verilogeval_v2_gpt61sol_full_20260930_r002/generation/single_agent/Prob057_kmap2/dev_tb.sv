`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire out;
    logic expected;
    logic [3:0] map_row;
    integer vector_index;
    integer column_index;

    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out));

    initial begin
        for (vector_index = 0; vector_index < 16; vector_index = vector_index + 1) begin
            {a, b, c, d} = vector_index[3:0];
            // Original map rows; bit 0 is column ab=00, then 01, 11, 10.
            case ({c, d})
                2'b00: map_row = 4'b1011;
                2'b01: map_row = 4'b1001;
                2'b11: map_row = 4'b1110;
                2'b10: map_row = 4'b0011;
            endcase
            case ({a, b})
                2'b00: column_index = 0;
                2'b01: column_index = 1;
                2'b11: column_index = 2;
                2'b10: column_index = 3;
            endcase
            expected = map_row[column_index];
            #1;
            if (out !== expected)
                $fatal(1, "Mismatch ab=%b%b cd=%b%b expected=%b actual=%b", a, b, c, d, expected, out);
        end
        $display("PASS: all 16 Karnaugh-map cells checked");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
