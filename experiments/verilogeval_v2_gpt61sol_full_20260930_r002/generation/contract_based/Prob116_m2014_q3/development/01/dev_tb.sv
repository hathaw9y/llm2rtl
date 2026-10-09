`timescale 1ns/1ps
module dev_tb;
    logic [4:1] x;
    wire f;
    integer checks = 0;
    TopModule dut (.x(x), .f(f));

    function automatic integer gray_index(input logic a, input logic b);
        case ({a,b})
            2'b00: gray_index = 0;
            2'b01: gray_index = 1;
            2'b11: gray_index = 2;
            2'b10: gray_index = 3;
            default: gray_index = -1;
        endcase
    endfunction

    task automatic check_vector(input logic [4:1] value);
        integer row_index, col_index;
        logic expected;
        begin
            x = value;
            #1;
            row_index = gray_index(value[3], value[4]);
            col_index = gray_index(value[1], value[2]);
            // Literal rows from the original map; x represents don't-care.
            case (row_index * 4 + col_index)
                0: expected = 1'bx;
                1: expected = 1'b0;
                2: expected = 1'bx;
                3: expected = 1'bx;
                4: expected = 1'b0;
                5: expected = 1'bx;
                6: expected = 1'b1;
                7: expected = 1'b0;
                8: expected = 1'b1;
                9: expected = 1'b1;
                10: expected = 1'bx;
                11: expected = 1'bx;
                12: expected = 1'b1;
                13: expected = 1'b1;
                14: expected = 1'b0;
                15: expected = 1'bx;
                default: $fatal(1, "Invalid map index");
            endcase
            if (expected !== 1'bx && f !== expected)
                $fatal(1, "x=%b row=%0d col=%0d expected=%b actual=%b",
                       value, row_index, col_index, expected, f);
            if (f !== 1'b0 && f !== 1'b1)
                $fatal(1, "Nonbinary output for binary input x=%b f=%b", value, f);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (integer i = 0; i < 16; i = i + 1)
            check_vector(4'(i));
        for (integer i = 15; i >= 0; i = i - 1)
            check_vector(4'(i));
        $display("PASS exhaustive original Karnaugh map checks=%0d", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Development test timeout");
    end
endmodule
