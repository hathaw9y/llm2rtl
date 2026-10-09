`timescale 1ns/1ps
module dev_tb;
    reg [4:1] x;
    wire f;
    integer row, col, pass_index, checks;
    reg expected;
    TopModule dut (.x(x), .f(f));

    // Gray-code ordering printed in the ORIGINAL Karnaugh map.
    function automatic [1:0] gray_pair(input integer index);
        case (index)
            0: gray_pair = 2'b00;
            1: gray_pair = 2'b01;
            2: gray_pair = 2'b11;
            3: gray_pair = 2'b10;
        endcase
    endfunction

    // Literal transcription: x marks an unconstrained don't-care cell.
    function automatic map_value(input integer r, input integer c);
        case (r*4+c)
            0: map_value = 1'bx;
            1: map_value = 1'b0;
            2: map_value = 1'bx;
            3: map_value = 1'bx;
            4: map_value = 1'b0;
            5: map_value = 1'bx;
            6: map_value = 1'b1;
            7: map_value = 1'b0;
            8: map_value = 1'b1;
            9: map_value = 1'b1;
            10: map_value = 1'bx;
            11: map_value = 1'bx;
            12: map_value = 1'b1;
            13: map_value = 1'b1;
            14: map_value = 1'b0;
            15: map_value = 1'bx;
        endcase
    endfunction

    task automatic check_cell(input integer r, input integer c);
        begin
            {x[3], x[4]} = gray_pair(r);
            {x[1], x[2]} = gray_pair(c);
            expected = map_value(r,c);
            #1;
            if (expected !== 1'bx && f !== expected)
                $fatal(1,"Map mismatch row=%0d col=%0d x=%b expected=%b got=%b",r,c,x,expected,f);
            if (f !== 1'b0 && f !== 1'b1)
                $fatal(1,"Nonbinary output for binary input x=%b",x);
            checks = checks + 1;
        end
    endtask

    initial begin
        checks = 0;
        for (row=0; row<4; row=row+1)
            for (col=0; col<4; col=col+1)
                check_cell(row,col);
        for (row=3; row>=0; row=row-1)
            for (col=3; col>=0; col=col-1)
                check_cell(row,col);
        $display("PASS: %0d original-map checks covering all 16 binary inputs",checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1,"Timeout");
    end
endmodule
