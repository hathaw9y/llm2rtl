`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d;
    wire out;
    reg [3:0] row_values;
    reg expected;
    integer i;

    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out));

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            {a, b, c, d} = i[3:0];
            // Encode each original K-map row in binary ab index order.
            case ({c, d})
                2'b00: row_values = 4'b0111;
                2'b01: row_values = 4'b0101;
                2'b11: row_values = 4'b1110;
                2'b10: row_values = 4'b0011;
            endcase
            expected = row_values[{a, b}];
            #1;
            if (out !== expected)
                $fatal(1, "Mismatch ab=%b%b cd=%b%b expected=%b actual=%b", a, b, c, d, expected, out);
        end
        $display("PASS: all 16 Karnaugh-map entries verified");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
