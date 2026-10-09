`timescale 1ns/1ps
module dev_tb;
    logic x3, x2, x1;
    wire f;
    integer checks = 0;
    TopModule dut (.x3(x3), .x2(x2), .x1(x1), .f(f));

    // Literal oracle copied from the original truth table, not the RTL equation.
    task automatic check_row(input logic [2:0] row);
        logic expected;
        begin
            case (row)
                3'b000: expected = 1'b0;
                3'b001: expected = 1'b0;
                3'b010: expected = 1'b1;
                3'b011: expected = 1'b1;
                3'b100: expected = 1'b0;
                3'b101: expected = 1'b1;
                3'b110: expected = 1'b0;
                3'b111: expected = 1'b1;
                default: $fatal(1, "Invalid test row");
            endcase
            {x3, x2, x1} = row;
            #1;
            if (f !== expected)
                $fatal(1, "row=%b expected=%b actual=%b", row, expected, f);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (integer row = 0; row < 8; row = row + 1)
            check_row(row[2:0]);
        // Exercise every ordered transition to detect stale outputs or latches.
        for (integer source = 0; source < 8; source = source + 1)
            for (integer destination = 0; destination < 8; destination = destination + 1) begin
                check_row(source[2:0]);
                check_row(destination[2:0]);
            end
        $display("PASS: all truth-table rows and ordered transitions (%0d checks)", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
