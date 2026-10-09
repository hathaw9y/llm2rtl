`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg a, b;
    wire out_assign, out_always_comb, out_always_ff;
    reg held = 1'bx;
    reg expected;
    integer i, j;
    TopModule dut (.clk(clk), .a(a), .b(b), .out_assign(out_assign),
                   .out_always_comb(out_always_comb), .out_always_ff(out_always_ff));

    function automatic reg value(input integer index);
        case (index)
            0: value = 1'b0;
            1: value = 1'b1;
            2: value = 1'bx;
            3: value = 1'bz;
        endcase
    endfunction

    // Independent truth-table oracle from the original XOR requirement.
    function automatic reg truth(input reg av, input reg bv);
        case ({av, bv})
            2'b00: truth = 1'b0;
            2'b01: truth = 1'b1;
            2'b10: truth = 1'b1;
            2'b11: truth = 1'b0;
            default: truth = 1'bx;
        endcase
    endfunction

    task automatic check(input reg comb_expected, input reg ff_expected);
        begin
            if (out_assign !== comb_expected)
                $fatal(1, "assign mismatch at %0t: a=%b b=%b got=%b expected=%b", $time,a,b,out_assign,comb_expected);
            if (out_always_comb !== comb_expected)
                $fatal(1, "comb mismatch at %0t", $time);
            if (out_always_ff !== ff_expected)
                $fatal(1, "ff mismatch at %0t: got=%b expected=%b", $time,out_always_ff,ff_expected);
        end
    endtask

    initial begin
        a = 0; b = 0;
        #1; check(1'b0, 1'bx);
        a = 1; b = 0;
        #1; check(1'b1, 1'bx);
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                a = value(i); b = value(j);
                expected = truth(a,b);
                #2; check(expected, held);
                clk = 1;
                held = expected;
                #1; check(expected, held);
                // Change data while high, then fall: register must hold.
                a = 0; b = ~held;
                #1; check(truth(a,b), held);
                clk = 0;
                #1; check(truth(a,b), held);
            end
        end
        // Two successive identical samples must remain stable.
        a = 1; b = 1;
        #1; check(0, held);
        clk = 1; held = 0;
        #1; check(0, held);
        clk = 0;
        #1; check(0, held);
        clk = 1;
        #1; check(0, held);
        $display("PASS: XOR truth table, four-state propagation, rising-edge capture and hold checks");
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
