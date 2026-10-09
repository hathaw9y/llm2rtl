`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d;
    wire out;
    reg [1:0] gray [0:3];
    reg [3:0] map_row [0:3];
    integer row, col, pass_index;
    reg expected;
    TopModule dut(.a(a), .b(b), .c(c), .d(d), .out(out));

    initial begin
        gray[0] = 2'b00;
        gray[1] = 2'b01;
        gray[2] = 2'b11;
        gray[3] = 2'b10;
        // Bit zero is the leftmost column (ab=00) of the given map.
        map_row[0] = 4'b1010;
        map_row[1] = 4'b0101;
        map_row[2] = 4'b1010;
        map_row[3] = 4'b0101;
        // Traverse in both directions to check combinational updates.
        for (pass_index = 0; pass_index < 2; pass_index = pass_index + 1) begin
            for (row = 0; row < 4; row = row + 1) begin
                for (col = 0; col < 4; col = col + 1) begin
                    if (pass_index == 0) begin
                        {a,b} = gray[col];
                        {c,d} = gray[row];
                        expected = map_row[row][col];
                    end else begin
                        {a,b} = gray[3-col];
                        {c,d} = gray[3-row];
                        expected = map_row[3-row][3-col];
                    end
                    #1;
                    if (out !== expected)
                        $fatal(1, "Map mismatch ab=%b%b cd=%b%b expected=%b got=%b", a,b,c,d,expected,out);
                end
            end
        end
        $display("PASS: all 16 Karnaugh-map cells checked in both directions");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
