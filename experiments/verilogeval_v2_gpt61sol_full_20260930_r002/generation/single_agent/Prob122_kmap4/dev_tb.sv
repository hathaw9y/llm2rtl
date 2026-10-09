`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire out;
    logic [3:0] map_row;
    logic expected;
    integer row_index, column_index;
    integer checked = 0;

    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out));

    initial begin
        #100;
        $fatal(1, "Timeout");
    end

    initial begin
        // Binary column index {a,b}; row values transcribed from the
        // original Gray-ordered map (columns 00, 01, 11, 10).
        for (row_index = 0; row_index < 4; row_index = row_index + 1) begin
            {c,d} = row_index[1:0];
            case ({c,d})
                2'b00: map_row = 4'b0110;
                2'b01: map_row = 4'b1001;
                2'b11: map_row = 4'b0110;
                2'b10: map_row = 4'b1001;
                default: $fatal(1, "Invalid test row");
            endcase
            for (column_index = 0; column_index < 4; column_index = column_index + 1) begin
                {a,b} = column_index[1:0];
                expected = map_row[column_index];
                #1;
                if (out !== expected)
                    $fatal(1, "Map mismatch ab=%b%b cd=%b%b expected=%b actual=%b", a,b,c,d,expected,out);
                checked = checked + 1;
            end
        end
        if (checked != 16) $fatal(1, "Incomplete coverage");
        $display("PASS: all 16 Karnaugh-map cells checked");
        $finish;
    end
endmodule
