`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic L = 0;
    logic q_in = 0;
    logic r_in = 0;
    wire Q;
    logic expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .L(L), .q_in(q_in), .r_in(r_in), .Q(Q));

    task automatic exercise(input logic sel, input logic qval, input logic rval);
        L = sel;
        q_in = qval;
        r_in = rval;
        #2;
        if (checks > 0 && Q !== expected)
            $fatal(1, "Output changed without rising edge");
        clk = 1;
        expected = sel ? rval : qval;
        #1;
        if (Q !== expected)
            $fatal(1, "Mux/flip-flop mismatch L=%b q_in=%b r_in=%b Q=%b", L, q_in, r_in, Q);
        checks = checks + 1;
        q_in = ~qval;
        r_in = ~rval;
        L = ~sel;
        #1;
        if (Q !== expected)
            $fatal(1, "Output changed while clock high");
        clk = 0;
        #1;
        if (Q !== expected)
            $fatal(1, "Output changed on falling edge");
    endtask

    initial begin
        for (integer pass = 0; pass < 2; pass = pass + 1)
            for (integer combination = 0; combination < 8; combination = combination + 1)
                exercise(combination[2], combination[1], combination[0]);
        $display("PASS: %0d cycles; all input combinations and between-edge stability", checks);
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "Testbench timeout");
    end
endmodule
