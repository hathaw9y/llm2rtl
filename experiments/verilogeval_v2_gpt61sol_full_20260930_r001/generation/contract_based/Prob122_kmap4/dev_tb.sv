`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire out;
    logic expected;
    integer row_index, column_index;
    integer vector_index, pass_index;
    integer checks = 0;
    logic map_values [0:3][0:3];
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out));

    function automatic integer gray_index(input logic [1:0] pair_value);
        case (pair_value)
            2'b00: gray_index = 0;
            2'b01: gray_index = 1;
            2'b11: gray_index = 2;
            2'b10: gray_index = 3;
            default: gray_index = 0;
        endcase
    endfunction

    initial begin
        map_values[0][0]=0; map_values[0][1]=1; map_values[0][2]=0; map_values[0][3]=1;
        map_values[1][0]=1; map_values[1][1]=0; map_values[1][2]=1; map_values[1][3]=0;
        map_values[2][0]=0; map_values[2][1]=1; map_values[2][2]=0; map_values[2][3]=1;
        map_values[3][0]=1; map_values[3][1]=0; map_values[3][2]=1; map_values[3][3]=0;
        for (pass_index=0; pass_index<2; pass_index=pass_index+1) begin
            for (vector_index=0; vector_index<16; vector_index=vector_index+1) begin
                if (pass_index == 0) {a,b,c,d} = 4'(vector_index);
                else {a,b,c,d} = 4'(15-vector_index);
                #1;
                row_index = gray_index({c,d});
                column_index = gray_index({a,b});
                expected = map_values[row_index][column_index];
                if (out !== expected)
                    $fatal(1, "FAIL abcd=%b%b%b%b expected=%b actual=%b", a,b,c,d,expected,out);
                checks = checks + 1;
            end
        end
        $display("PASS: %0d comparisons; all 16 binary combinations in both directions", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: development test timeout");
    end
endmodule
