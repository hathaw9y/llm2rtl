`timescale 1ns/1ps
module dev_tb;
    logic x3, x2, x1;
    wire f;
    localparam logic [7:0] TABLE = 8'b10101100;
    integer i;
    integer checks = 0;

    TopModule dut (.x3(x3), .x2(x2), .x1(x1), .f(f));

    task automatic check_row(input logic [2:0] row);
        begin
            {x3, x2, x1} = row;
            #1;
            if (f !== TABLE[row])
                $fatal(1, "row %b: expected %b, got %b", row, TABLE[row], f);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Exhaustive rows in both directions check combinational transitions.
        for (i = 0; i < 8; i = i + 1)
            check_row(i[2:0]);
        for (i = 7; i >= 0; i = i - 1)
            check_row(i[2:0]);
        $display("PASS: %0d truth-table checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "timeout");
    end
endmodule
