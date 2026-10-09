`timescale 1ns/1ps
module dev_tb;
    logic [4:1] x;
    wire f;
    integer row_idx, col_idx, checked;
    logic [1:0] row_bits, col_bits;
    logic expected;
    TopModule dut (.x(x), .f(f));

    function automatic logic [1:0] gray_bits(input integer index);
        case (index)
            0: gray_bits = 2'b00;
            1: gray_bits = 2'b01;
            2: gray_bits = 2'b11;
            3: gray_bits = 2'b10;
            default: gray_bits = 2'bxx;
        endcase
    endfunction

    // Literal transcription of the original map; X denotes a don't-care.
    function automatic logic map_value(input integer row, input integer col);
        case (row * 4 + col)
            1, 4, 7, 14: map_value = 1'b0;
            6, 8, 9, 12, 13: map_value = 1'b1;
            default: map_value = 1'bx;
        endcase
    endfunction

    initial begin
        checked = 0;
        for (row_idx = 0; row_idx < 4; row_idx = row_idx + 1) begin
            for (col_idx = 0; col_idx < 4; col_idx = col_idx + 1) begin
                row_bits = gray_bits(row_idx);
                col_bits = gray_bits(col_idx);
                {x[3], x[4]} = row_bits;
                {x[1], x[2]} = col_bits;
                expected = map_value(row_idx, col_idx);
                #1;
                if (expected !== 1'bx) begin
                    if (f !== expected)
                        $fatal(1, "Map mismatch row=%b col=%b x=%b expected=%b actual=%b",
                               row_bits, col_bits, x, expected, f);
                    checked = checked + 1;
                end else if ((f !== 1'b0) && (f !== 1'b1)) begin
                    $fatal(1, "Unknown output for binary input x=%b", x);
                end
            end
        end
        if (checked != 9) $fatal(1, "Incorrect care-cell coverage: %0d", checked);
        $display("PASS all 16 map cells exercised; all 9 specified outputs checked");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
