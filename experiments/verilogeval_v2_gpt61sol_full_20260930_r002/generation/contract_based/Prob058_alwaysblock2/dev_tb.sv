`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic a = 1'b0;
    logic b = 1'b0;
    wire out_assign, out_always_comb, out_always_ff;
    logic expected_ff = 1'bx;
    logic values [0:3];
    integer i, j;
    integer checks = 0;

    TopModule dut (.clk(clk), .a(a), .b(b),
        .out_assign(out_assign), .out_always_comb(out_always_comb),
        .out_always_ff(out_always_ff));

    // Truth-table oracle derived from the original XOR requirement.
    function automatic logic expected_xor(input logic left, input logic right);
        case ({left, right})
            2'b00, 2'b11: expected_xor = 1'b0;
            2'b01, 2'b10: expected_xor = 1'b1;
            default: expected_xor = 1'bx;
        endcase
    endfunction

    task automatic check_outputs;
        logic expected_comb;
        begin
            expected_comb = expected_xor(a, b);
            if (out_assign !== expected_comb)
                $fatal(1, "assign mismatch a=%b b=%b got=%b expected=%b", a, b, out_assign, expected_comb);
            if (out_always_comb !== expected_comb)
                $fatal(1, "comb mismatch a=%b b=%b got=%b expected=%b", a, b, out_always_comb, expected_comb);
            if (out_always_ff !== expected_ff)
                $fatal(1, "ff mismatch clk=%b a=%b b=%b got=%b expected=%b", clk, a, b, out_always_ff, expected_ff);
            checks = checks + 1;
        end
    endtask

    task automatic exercise(input logic left, input logic right);
        begin
            // Inputs change while low: combinational outputs follow, FF holds.
            a = left;
            b = right;
            #1;
            check_outputs();
            expected_ff = expected_xor(left, right);
            clk = 1'b1;
            #1; // Observe after nonblocking assignments settle.
            check_outputs();
            // Change inputs while high without a rising edge.
            a = ~left;
            b = right;
            #1;
            check_outputs();
            clk = 1'b0;
            #1;
            check_outputs();
        end
    endtask

    initial begin
        values[0] = 1'b0;
        values[1] = 1'b1;
        values[2] = 1'bx;
        values[3] = 1'bz;
        #1;
        check_outputs(); // Uninitialized register before any positive edge.
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1)
                exercise(values[i], values[j]);
        // Recover known values after unknown samples and repeat binary cases.
        exercise(1'b0, 1'b1);
        exercise(1'b1, 1'b1);
        exercise(1'b1, 1'b0);
        exercise(1'b0, 1'b0);
        $display("PASS: XOR truth table, positive-edge sampling, and hold checks (%0d checks)", checks);
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
