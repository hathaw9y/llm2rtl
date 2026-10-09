`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d;
    wire out;
    reg expected;
    reg specified;
    integer i;
    integer checked = 0;
    TopModule dut(.a(a), .b(b), .c(c), .d(d), .out(out));

    // Truth table directly transcribed from the original K-map.
    // Index is {a,b,c,d}; don't-care cells impose no expected value.
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            {a,b,c,d} = i;
            specified = 1;
            case (i)
                0, 1, 5, 6, 7: expected = 0;
                2, 3, 8, 10, 11, 12, 14, 15: expected = 1;
                4, 9, 13: begin specified = 0; expected = 1'bx; end
                default: $fatal(1, "Unexpected test index");
            endcase
            #1;
            if (specified) begin
                if (out !== expected)
                    $fatal(1, "Mismatch abcd=%b expected=%b actual=%b", {a,b,c,d}, expected, out);
                checked = checked + 1;
            end
        end
        if (checked != 13) $fatal(1, "Incomplete specified-cell coverage");
        $display("PASS: all 13 specified K-map cells checked; all 16 combinations exercised");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
