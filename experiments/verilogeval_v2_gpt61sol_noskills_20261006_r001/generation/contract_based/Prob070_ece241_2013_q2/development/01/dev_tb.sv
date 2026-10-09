`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d;
    wire out_sop, out_pos;
    integer i;
    integer checked = 0;
    TopModule dut (.a(a), .b(b), .c(c), .d(d),
                   .out_sop(out_sop), .out_pos(out_pos));

    task automatic check_input(input integer value);
        reg expected;
        reg specified;
        begin
            {a, b, c, d} = value[3:0];
            #1;
            specified = 1'b1;
            case (value)
                2, 7, 15: expected = 1'b1;
                0, 1, 4, 5, 6, 9, 10, 13, 14: expected = 1'b0;
                3, 8, 11, 12: begin
                    specified = 1'b0;
                    expected = 1'bx;
                end
                default: $fatal(1, "Invalid test stimulus %0d", value);
            endcase
            if (specified) begin
                if (out_sop !== expected || out_pos !== expected)
                    $fatal(1, "Input %0d (%b%b%b%b): expected %b, sop=%b pos=%b",
                           value, a, b, c, d, expected, out_sop, out_pos);
                checked = checked + 1;
            end
        end
    endtask

    initial begin
        for (i = 0; i < 16; i = i + 1) check_input(i);
        for (i = 15; i >= 0; i = i - 1) check_input(i);
        if (checked != 24) $fatal(1, "Coverage count mismatch: %0d", checked);
        $display("PASS: both outputs passed all 12 specified inputs in both sweep directions");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Development test timeout");
    end
endmodule
