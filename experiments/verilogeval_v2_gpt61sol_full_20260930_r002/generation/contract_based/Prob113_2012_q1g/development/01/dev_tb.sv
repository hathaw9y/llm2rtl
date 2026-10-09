`timescale 1ns/1ps
module dev_tb;
    logic [3:0] x;
    wire f;
    integer i;
    integer checks = 0;
    TopModule dut (.x(x), .f(f));

    function automatic integer gray_index(input logic [1:0] pair);
        case (pair)
            2'b00: gray_index = 0;
            2'b01: gray_index = 1;
            2'b11: gray_index = 2;
            2'b10: gray_index = 3;
            default: gray_index = -1;
        endcase
    endfunction

    function automatic logic original_map(input logic [3:0] value);
        integer row;
        integer col;
        logic [3:0] cells;
        begin
            row = gray_index({value[2], value[3]});
            col = gray_index({value[0], value[1]});
            // Bit zero is the first displayed column (00).
            case (row)
                0: cells = 4'b1001;
                1: cells = 4'b0000;
                2: cells = 4'b0111;
                3: cells = 4'b1011;
                default: cells = 4'bxxxx;
            endcase
            original_map = cells[col];
        end
    endfunction

    task automatic check_input(input logic [3:0] value);
        logic expected;
        begin
            x = value;
            expected = original_map(value);
            #1;
            if (f !== expected)
                $fatal(1, "Mismatch x=%b expected=%b actual=%b", x, expected, f);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (i = 0; i < 16; i = i + 1)
            check_input(i[3:0]);
        for (i = 15; i >= 0; i = i - 1)
            check_input(i[3:0]);
        $display("PASS: %0d original Karnaugh-map checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
