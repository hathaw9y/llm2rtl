`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d;
    wire out_sop, out_pos;
    integer i;
    integer checked = 0;
    reg expected;
    reg specified;

    TopModule dut(.a(a), .b(b), .c(c), .d(d),
                  .out_sop(out_sop), .out_pos(out_pos));

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            {a,b,c,d} = i[3:0];
            specified = 1'b1;
            case (i)
                2, 7, 15: expected = 1'b1;
                0, 1, 4, 5, 6, 9, 10, 13, 14: expected = 1'b0;
                default: begin
                    specified = 1'b0;
                    expected = 1'bx;
                end
            endcase
            #1;
            if (specified) begin
                if (out_sop !== expected || out_pos !== expected)
                    $fatal(1, "Input %0d: expected %b, SOP=%b POS=%b", i, expected, out_sop, out_pos);
                checked = checked + 1;
            end
        end
        if (checked != 12) $fatal(1, "Coverage count incorrect: %0d", checked);
        $display("PASS: all 12 specified input combinations checked");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
