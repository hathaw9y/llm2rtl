module dev_tb;
    logic [4:1] x;
    logic f;
    integer row_idx, col_idx, checked;
    logic [1:0] gray [0:3];
    logic expected [0:3][0:3];
    TopModule dut (.x(x), .f(f));
    initial begin
        gray[0] = 2'b00; gray[1] = 2'b01;
        gray[2] = 2'b11; gray[3] = 2'b10;
        expected[0][0] = 1'bx; expected[0][1] = 0; expected[0][2] = 1'bx; expected[0][3] = 1'bx;
        expected[1][0] = 0; expected[1][1] = 1'bx; expected[1][2] = 1; expected[1][3] = 0;
        expected[2][0] = 1; expected[2][1] = 1; expected[2][2] = 1'bx; expected[2][3] = 1'bx;
        expected[3][0] = 1; expected[3][1] = 1; expected[3][2] = 0; expected[3][3] = 1'bx;
        checked = 0;
        for (row_idx = 0; row_idx < 4; row_idx = row_idx + 1) begin
            for (col_idx = 0; col_idx < 4; col_idx = col_idx + 1) begin
                {x[3], x[4]} = gray[row_idx];
                {x[1], x[2]} = gray[col_idx];
                #1;
                if (expected[row_idx][col_idx] !== 1'bx) begin
                    checked = checked + 1;
                    if (f !== expected[row_idx][col_idx])
                        $fatal(1, "FAIL x=%b expected=%b actual=%b", x, expected[row_idx][col_idx], f);
                end
            end
        end
        $display("PASS: all 16 inputs exercised, %0d specified cells checked", checked);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
