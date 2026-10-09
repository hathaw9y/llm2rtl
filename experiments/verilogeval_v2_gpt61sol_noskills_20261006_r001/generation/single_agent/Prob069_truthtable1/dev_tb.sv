`timescale 1ns/1ps
module dev_tb;
    reg x3, x2, x1;
    wire f;
    reg [7:0] expected;
    integer previous, current;
    TopModule dut (.x3(x3), .x2(x2), .x1(x1), .f(f));

    task check_row(input integer row);
        begin
            {x3, x2, x1} = row[2:0];
            #1;
            if (f !== expected[row])
                $fatal(1, "Row %03b: expected %b, got %b", row[2:0], expected[row], f);
        end
    endtask

    initial begin
        // Bits 0 through 7 are the original truth-table outputs.
        expected = 8'b10101100;
        for (current = 0; current < 8; current = current + 1)
            check_row(current);
        // Exercise every ordered input transition to detect retained state.
        for (previous = 0; previous < 8; previous = previous + 1)
            for (current = 0; current < 8; current = current + 1) begin
                check_row(previous);
                check_row(current);
            end
        $display("PASS: all eight rows and all 64 ordered transitions");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
