`timescale 1ns/1ps
module dev_tb;
    reg [3:0] x;
    wire f;
    reg [1:0] gray [0:3];
    reg [3:0] map_rows [0:3];
    reg expected;
    integer row, col, pass_index;
    TopModule dut (.x(x), .f(f));

    initial begin
        gray[0] = 2'b00;
        gray[1] = 2'b01;
        gray[2] = 2'b11;
        gray[3] = 2'b10;
        // Original map, left to right, with rows ordered 00, 01, 11, 10.
        map_rows[0] = 4'b1001;
        map_rows[1] = 4'b0000;
        map_rows[2] = 4'b1110;
        map_rows[3] = 4'b1101;
        // Repeat in reverse order to check both directions of input changes.
        for (pass_index = 0; pass_index < 2; pass_index = pass_index + 1) begin
            for (row = 0; row < 4; row = row + 1) begin
                for (col = 0; col < 4; col = col + 1) begin
                    if (pass_index == 0) begin
                        {x[2], x[3]} = gray[row];
                        {x[0], x[1]} = gray[col];
                        expected = map_rows[row][3-col];
                    end else begin
                        {x[2], x[3]} = gray[3-row];
                        {x[0], x[1]} = gray[3-col];
                        expected = map_rows[3-row][col];
                    end
                    #1;
                    if (f !== expected)
                        $fatal(1, "x=%b f=%b expected=%b", x, f, expected);
                end
            end
        end
        $display("PASS all 16 Karnaugh-map cells checked in both directions");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
