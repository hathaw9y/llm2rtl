`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire out;
    logic [3:0] map_rows [0:3];
    integer i;
    integer checked;

    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out));

    function automatic integer gray_index(input logic [1:0] pair_bits);
        case (pair_bits)
            2'b00: gray_index = 0;
            2'b01: gray_index = 1;
            2'b11: gray_index = 2;
            2'b10: gray_index = 3;
            default: gray_index = -1;
        endcase
    endfunction

    task automatic check_vector(input logic [3:0] vector_bits);
        logic expected;
        integer row_index, col_index;
        begin
            {a,b,c,d} = vector_bits;
            #1;
            row_index = gray_index({c,d});
            col_index = gray_index({a,b});
            expected = map_rows[row_index][col_index];
            if (out !== expected)
                $fatal(1, "abcd=%b expected=%b observed=%b", vector_bits, expected, out);
            checked = checked + 1;
        end
    endtask

    initial begin
        // Bit index 0 is the leftmost (ab=00) column of the original map.
        map_rows[0] = 4'b1010;
        map_rows[1] = 4'b0101;
        map_rows[2] = 4'b1010;
        map_rows[3] = 4'b0101;
        checked = 0;
        for (i = 0; i < 16; i = i + 1)
            check_vector(i[3:0]);
        for (i = 15; i >= 0; i = i - 1)
            check_vector(i[3:0]);
        $display("PASS: original Karnaugh map verified in %0d checks", checked);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
