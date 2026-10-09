`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic aresetn = 1;
    logic x = 0;
    wire z;
    logic [1:0] history;
    integer count, checks = 0;
    TopModule dut (.clk(clk), .aresetn(aresetn), .x(x), .z(z));
    always #5 clk = ~clk;

    task automatic reset_dut;
        @(negedge clk);
        #1 aresetn = 0;
        history = 0;
        count = 0;
        #1;
        if (z !== 1'b0) $fatal(1, "Asynchronous reset failed");
        #1 aresetn = 1;
    endtask

    task automatic send_bit(input logic bit_value);
        logic expected;
        @(negedge clk);
        x = bit_value;
        #1;
        expected = (count >= 2 && history == 2'b10 && bit_value);
        if (z !== expected)
            $fatal(1, "Mismatch history=%b count=%0d x=%b z=%b expected=%b", history, count, x, z, expected);
        checks = checks + 1;
        @(posedge clk);
        history = {history[0], bit_value};
        if (count < 2) count = count + 1;
        #1;
    endtask

    initial begin
        reset_dut();
        // Exhaust all 10-bit streams, including overlapping detections.
        for (integer pattern = 0; pattern < 1024; pattern = pattern + 1) begin
            reset_dut();
            for (integer bit_index = 9; bit_index >= 0; bit_index = bit_index - 1)
                send_bit((pattern >> bit_index) & 1);
        end
        // Reset while a detection is active, between clock edges.
        reset_dut();
        send_bit(1); send_bit(0);
        @(negedge clk); x = 1;
        #1;
        if (z !== 1) $fatal(1, "Directed detection failed");
        aresetn = 0;
        #1;
        if (z !== 0) $fatal(1, "Reset did not clear active detection asynchronously");
        $display("PASS: %0d bit comparisons plus asynchronous reset checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Testbench timeout");
    end
endmodule
