`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d;
    wire out;
    reg [3:0] map_rows [0:3];
    integer i, row_index, column_index;
    reg expected;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out));

    function integer gray_index(input [1:0] value);
        case (value)
            2'b00: gray_index = 0;
            2'b01: gray_index = 1;
            2'b11: gray_index = 2;
            2'b10: gray_index = 3;
        endcase
    endfunction

    task check_combination(input [3:0] stimulus);
        begin
            {a,b,c,d} = stimulus;
            #1;
            row_index = gray_index({c,d});
            column_index = gray_index({a,b});
            expected = map_rows[row_index][3-column_index];
            if (out !== expected)
                $fatal(1, "Mismatch ab=%b%b cd=%b%b expected=%b actual=%b", a,b,c,d,expected,out);
        end
    endtask

    initial begin
        // Each literal lists the original columns 00, 01, 11, 10 left to right.
        map_rows[0] = 4'b0101; // cd=00
        map_rows[1] = 4'b1010; // cd=01
        map_rows[2] = 4'b0101; // cd=11
        map_rows[3] = 4'b1010; // cd=10
        for (i=0; i<16; i=i+1) check_combination(i[3:0]);
        for (i=15; i>=0; i=i-1) check_combination(i[3:0]);
        $display("PASS: all 16 Karnaugh map entries checked in both traversal directions");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Development test timeout");
    end
endmodule
