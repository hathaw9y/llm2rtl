`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire out;
    integer i;
    integer checked;
    logic expected;
    logic care;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out));

    // Explicit table from original map, indexed by {a,b,c,d}.
    task automatic check_cell(input integer cell_index);
        begin
            {a,b,c,d} = cell_index[3:0];
            care = 1'b1;
            case (cell_index)
                0, 1, 5, 6, 7: expected = 1'b0;
                2, 3, 8, 10, 11, 12, 14, 15: expected = 1'b1;
                4, 9, 13: begin care = 1'b0; expected = 1'bx; end
                default: $fatal(1, "Invalid test index");
            endcase
            #1;
            if (care) begin
                if (out !== expected)
                    $fatal(1, "abcd=%b expected=%b actual=%b", {a,b,c,d}, expected, out);
                checked = checked + 1;
            end
        end
    endtask

    initial begin
        checked = 0;
        for (i = 0; i < 16; i = i + 1) check_cell(i);
        // Reverse traversal checks combinational updates after different predecessors.
        for (i = 15; i >= 0; i = i - 1) check_cell(i);
        if (checked != 26) $fatal(1, "Incomplete truth-table coverage");
        $display("PASS: all 13 specified cells checked in both traversal directions");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
