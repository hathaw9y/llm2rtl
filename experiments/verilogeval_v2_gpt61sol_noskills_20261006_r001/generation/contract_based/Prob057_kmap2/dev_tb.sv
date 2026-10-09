`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d;
    wire out;
    reg [3:0] map_rows [0:3];
    integer row, col, sweep, checks;
    reg expected;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out));

    function automatic [1:0] gray(input integer index);
        case (index)
            0: gray = 2'b00;
            1: gray = 2'b01;
            2: gray = 2'b11;
            3: gray = 2'b10;
            default: gray = 2'bxx;
        endcase
    endfunction

    initial begin
        // Literal rows from the original map, leftmost column in bit 3.
        map_rows[0] = 4'b1101;
        map_rows[1] = 4'b1001;
        map_rows[2] = 4'b0111;
        map_rows[3] = 4'b1100;
        checks = 0;
        for (sweep = 0; sweep < 2; sweep = sweep + 1) begin
            for (row = 0; row < 4; row = row + 1) begin
                for (col = 0; col < 4; col = col + 1) begin
                    if (sweep == 0) begin
                        {a,b} = gray(col);
                        {c,d} = gray(row);
                        expected = map_rows[row][3-col];
                    end else begin
                        {a,b} = gray(3-col);
                        {c,d} = gray(3-row);
                        expected = map_rows[3-row][col];
                    end
                    #1;
                    if (out !== expected)
                        $fatal(1, "Map mismatch ab=%b%b cd=%b%b expected=%b actual=%b", a,b,c,d,expected,out);
                    checks = checks + 1;
                end
            end
        end
        $display("PASS: %0d checks covering all 16 Karnaugh map cells", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Bounded timeout");
    end
endmodule
