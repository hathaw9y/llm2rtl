`timescale 1ns/1ps
module dev_tb;
    logic [3:0] x;
    wire f;
    logic expected;
    logic kmap [0:3][0:3];
    integer row_index, col_index;
    integer checks;
    TopModule dut (.x(x), .f(f));

    function automatic integer gray_index(input logic a, input logic b);
        case ({a,b})
            2'b00: gray_index = 0;
            2'b01: gray_index = 1;
            2'b11: gray_index = 2;
            2'b10: gray_index = 3;
        endcase
    endfunction

    task automatic check_vector(input logic [3:0] vector);
        x = vector;
        #1;
        row_index = gray_index(x[2], x[3]);
        col_index = gray_index(x[0], x[1]);
        expected = kmap[row_index][col_index];
        if (f !== expected)
            $fatal(1, "FAIL x=%b expected=%b actual=%b", x, expected, f);
        checks = checks + 1;
    endtask

    initial begin
        kmap[0][0]=1; kmap[0][1]=0; kmap[0][2]=0; kmap[0][3]=1;
        kmap[1][0]=0; kmap[1][1]=0; kmap[1][2]=0; kmap[1][3]=0;
        kmap[2][0]=1; kmap[2][1]=1; kmap[2][2]=1; kmap[2][3]=0;
        kmap[3][0]=1; kmap[3][1]=1; kmap[3][2]=0; kmap[3][3]=1;
        checks = 0;
        for (integer i=0; i<16; i=i+1) check_vector(4'(i));
        for (integer i=15; i>=0; i=i-1) check_vector(4'(i));
        $display("PASS: %0d comparisons, all 16 binary inputs in both orders", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
