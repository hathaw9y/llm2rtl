`timescale 1ns/1ps
module dev_tb;
    logic [3:0] x;
    wire f;
    logic expected;
    logic [3:0] row_values;
    integer i;
    integer column_index;
    TopModule dut (.x(x), .f(f));
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            x = i[3:0];
            // Bits of each row list columns 00, 01, 11, 10, in that order.
            case ({x[2], x[3]})
                2'b00: row_values = 4'b1001;
                2'b01: row_values = 4'b0000;
                2'b11: row_values = 4'b0111;
                2'b10: row_values = 4'b1011;
            endcase
            case ({x[0], x[1]})
                2'b00: column_index = 0;
                2'b01: column_index = 1;
                2'b11: column_index = 2;
                2'b10: column_index = 3;
            endcase
            expected = row_values[column_index];
            #1;
            if (f !== expected)
                $fatal(1, "FAIL x=%b expected=%b actual=%b", x, expected, f);
        end
        $display("PASS: all 16 Karnaugh-map inputs matched");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
