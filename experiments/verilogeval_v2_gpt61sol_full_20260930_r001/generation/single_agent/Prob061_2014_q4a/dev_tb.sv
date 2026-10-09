`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic w, R, E, L;
    logic Q;
    logic expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .w(w), .R(R), .E(E), .L(L), .Q(Q));
    always #5 clk = ~clk;

    task automatic step(input logic load, enable, load_value, shift_value);
        @(negedge clk);
        L = load;
        E = enable;
        R = load_value;
        w = shift_value;
        #1;
        if (Q !== expected) $fatal(1, "Output changed before rising edge");
        @(posedge clk);
        if (load) expected = load_value;
        else if (enable) expected = shift_value;
        #1;
        if (Q !== expected)
            $fatal(1, "Mismatch L=%b E=%b R=%b w=%b expected=%b actual=%b", L, E, R, w, expected, Q);
        checks = checks + 1;
    endtask

    initial begin
        L = 1'b1; E = 1'b0; R = 1'b0; w = 1'b0;
        expected = 1'b0;
        @(posedge clk);
        #1;
        if (Q !== expected) $fatal(1, "Initial load failed");
        for (integer prior = 0; prior < 2; prior = prior + 1) begin
            for (integer inputs = 0; inputs < 16; inputs = inputs + 1) begin
                step(1'b1, 1'b0, prior[0], 1'b0);
                step(inputs[3], inputs[2], inputs[1], inputs[0]);
            end
        end
        $display("PASS: %0d checked cycles, all binary control/data combinations from both prior states", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Testbench timeout");
    end
endmodule
