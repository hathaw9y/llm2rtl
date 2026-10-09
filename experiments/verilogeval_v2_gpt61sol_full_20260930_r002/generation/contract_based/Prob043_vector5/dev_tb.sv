`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d, e;
    wire [24:0] out;
    logic inputs_by_index [0:4];
    logic [24:0] expected;
    integer pattern, row, column, index, digit, checks;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .e(e), .out(out));

    task automatic drive_and_check;
        begin
            a = inputs_by_index[0];
            b = inputs_by_index[1];
            c = inputs_by_index[2];
            d = inputs_by_index[3];
            e = inputs_by_index[4];
            for (row = 0; row < 5; row = row + 1) begin
                for (column = 0; column < 5; column = column + 1) begin
                    if ((inputs_by_index[row] === 1'bx) ||
                        (inputs_by_index[row] === 1'bz) ||
                        (inputs_by_index[column] === 1'bx) ||
                        (inputs_by_index[column] === 1'bz))
                        expected[24 - row*5 - column] = 1'bx;
                    else
                        expected[24 - row*5 - column] =
                            (inputs_by_index[row] == inputs_by_index[column]);
                end
            end
            #1;
            if (out !== expected)
                $fatal(1, "Mismatch inputs=%b%b%b%b%b got=%b expected=%b", a,b,c,d,e,out,expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        checks = 0;
        for (pattern = 0; pattern < 32; pattern = pattern + 1) begin
            for (index = 0; index < 5; index = index + 1)
                inputs_by_index[index] = ((pattern >> (4-index)) & 1);
            drive_and_check();
        end
        for (pattern = 31; pattern >= 0; pattern = pattern - 1) begin
            for (index = 0; index < 5; index = index + 1)
                inputs_by_index[index] = ((pattern >> (4-index)) & 1);
            drive_and_check();
        end
        for (pattern = 0; pattern < 1024; pattern = pattern + 1) begin
            for (index = 0; index < 5; index = index + 1) begin
                digit = (pattern >> (2*index)) & 3;
                case (digit)
                    0: inputs_by_index[index] = 1'b0;
                    1: inputs_by_index[index] = 1'b1;
                    2: inputs_by_index[index] = 1'bx;
                    3: inputs_by_index[index] = 1'bz;
                endcase
            end
            drive_and_check();
        end
        $display("PASS: %0d exhaustive binary and four-state matrix checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
