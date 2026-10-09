`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire out_sop, out_pos;
    integer value;
    integer checked;
    logic expected;
    logic defined_input;

    TopModule dut (.a(a), .b(b), .c(c), .d(d),
                   .out_sop(out_sop), .out_pos(out_pos));

    task automatic check_input(input integer number);
        begin
            {a, b, c, d} = number[3:0];
            // Truth-table oracle from the original specification.
            defined_input = 1'b1;
            case (number)
                2, 7, 15: expected = 1'b1;
                0, 1, 4, 5, 6, 9, 10, 13, 14: expected = 1'b0;
                3, 8, 11, 12: begin
                    defined_input = 1'b0;
                    expected = 1'bx;
                end
                default: $fatal(1, "Invalid test input %0d", number);
            endcase
            #1;
            if (defined_input) begin
                if (out_sop !== expected || out_pos !== expected)
                    $fatal(1, "Input %0d expected %b: SOP=%b POS=%b",
                           number, expected, out_sop, out_pos);
                checked = checked + 1;
            end
        end
    endtask

    initial begin
        checked = 0;
        for (value = 0; value < 16; value = value + 1)
            check_input(value);
        // Reverse traversal exercises transitions after every input pattern.
        for (value = 15; value >= 0; value = value - 1)
            check_input(value);
        if (checked != 24)
            $fatal(1, "Incorrect check count: %0d", checked);
        $display("PASS all defined truth-table entries in both traversal orders");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
