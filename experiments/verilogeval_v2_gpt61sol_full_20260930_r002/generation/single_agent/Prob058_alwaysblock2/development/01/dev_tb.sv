`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic a = 0;
    logic b = 0;
    wire out_assign, out_always_comb, out_always_ff;
    logic held = 1'bx;
    integer i, j;
    TopModule dut (.*);

    function automatic logic symbol(input integer n);
        case (n)
            0: symbol = 1'b0;
            1: symbol = 1'b1;
            2: symbol = 1'bx;
            3: symbol = 1'bz;
        endcase
    endfunction

    function automatic logic expected(input logic av, bv);
        case ({av, bv})
            2'b00, 2'b11: expected = 1'b0;
            2'b01, 2'b10: expected = 1'b1;
            default: expected = 1'bx;
        endcase
    endfunction

    task automatic check_outputs;
        if (out_assign !== expected(a,b))
            $fatal(1, "assign mismatch a=%b b=%b", a, b);
        if (out_always_comb !== expected(a,b))
            $fatal(1, "combinational mismatch a=%b b=%b", a, b);
        if (out_always_ff !== held)
            $fatal(1, "registered mismatch expected=%b actual=%b", held, out_always_ff);
    endtask

    initial begin
        #1;
        check_outputs();
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                a = symbol(i);
                b = symbol(j);
                #1;
                check_outputs();
                held = expected(a,b);
                clk = 1;
                #1;
                check_outputs();
                // Change inputs while clock is high: only combinational outputs respond.
                a = ~symbol(i);
                b = symbol(j);
                #1;
                check_outputs();
                clk = 0;
                #1;
                check_outputs();
            end
        end
        $display("PASS: XOR truth table, four-state propagation, rising-edge capture and hold");
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "timeout");
    end
endmodule
