`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d;
    wire out, out_n;
    integer i;
    reg expected;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out), .out_n(out_n));

    // Independent binary oracle: these are exactly the minterms where
    // either input pair is simultaneously high.
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            {a,b,c,d} = i;
            case (i)
                3, 7, 11, 12, 13, 14, 15: expected = 1'b1;
                default: expected = 1'b0;
            endcase
            #1;
            if (out !== expected || out_n !== ~expected)
                $fatal(1, "Input %04b: out=%b out_n=%b expected=%b", {a,b,c,d}, out, out_n, expected);
        end
        // Gate controlling values and unknown propagation.
        {a,b,c,d} = 4'b0x0z;
        #1;
        if (out !== 1'b0 || out_n !== 1'b1) $fatal(1, "Zero controlling values failed");
        {a,b,c,d} = 4'b11xz;
        #1;
        if (out !== 1'b1 || out_n !== 1'b0) $fatal(1, "OR controlling value failed");
        {a,b,c,d} = 4'b1x00;
        #1;
        if (out !== 1'bx || out_n !== 1'bx) $fatal(1, "Unknown propagation failed");
        $display("PASS exhaustive binary combinations and four-state gate cases");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
