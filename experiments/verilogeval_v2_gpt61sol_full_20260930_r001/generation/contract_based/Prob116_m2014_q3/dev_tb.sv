`timescale 1ns/1ps
module dev_tb;
    logic [4:1] x;
    wire f;
    integer checked = 0;
    integer row_index, column_index;
    logic expected;
    TopModule dut (.x(x), .f(f));

    function automatic integer gray_index(input logic [1:0] bits);
        case (bits)
            2'b00: gray_index = 0;
            2'b01: gray_index = 1;
            2'b11: gray_index = 2;
            2'b10: gray_index = 3;
        endcase
    endfunction

    // Direct transcription of the original map, with x marking don't-cares.
    function automatic logic map_value(input integer row, input integer col);
        case (row)
            0: case (col)
                0: map_value=1'bx; 1: map_value=1'b0;
                2: map_value=1'bx; 3: map_value=1'bx;
            endcase
            1: case (col)
                0: map_value=1'b0; 1: map_value=1'bx;
                2: map_value=1'b1; 3: map_value=1'b0;
            endcase
            2: case (col)
                0: map_value=1'b1; 1: map_value=1'b1;
                2: map_value=1'bx; 3: map_value=1'bx;
            endcase
            3: case (col)
                0: map_value=1'b1; 1: map_value=1'b1;
                2: map_value=1'b0; 3: map_value=1'bx;
            endcase
            default: map_value=1'bx;
        endcase
    endfunction

    task automatic check_input(input logic [4:1] value);
        x = value;
        #1;
        row_index = gray_index({x[3], x[4]});
        column_index = gray_index({x[1], x[2]});
        expected = map_value(row_index, column_index);
        if (f !== 1'b0 && f !== 1'b1)
            $fatal(1, "Nonbinary output x=%b f=%b", x, f);
        if (expected !== 1'bx && f !== expected)
            $fatal(1, "Mismatch x=%b expected=%b actual=%b", x, expected, f);
        checked = checked + 1;
    endtask

    initial begin
        for (integer i=0; i<16; i=i+1) check_input(4'(i));
        for (integer i=15; i>=0; i=i-1) check_input(4'(i));
        $display("PASS: %0d checks; all 16 inputs in both directions", checked);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Development timeout");
    end
endmodule
