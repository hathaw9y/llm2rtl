`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic j = 0;
    logic k = 0;
    wire out;
    logic expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .areset(areset), .j(j), .k(k), .out(out));
    always #5 clk = ~clk;

    task automatic check(input logic value);
        begin
            if (out !== value)
                $fatal(1, "Mismatch: out=%b expected=%b", out, value);
            checks = checks + 1;
        end
    endtask

    task automatic step(input logic j_value, input logic k_value);
        begin
            @(negedge clk);
            j = j_value;
            k = k_value;
            #1;
            check(expected);
            @(posedge clk);
            expected = expected ? !k_value : j_value;
            #1;
            check(expected);
        end
    endtask

    initial begin
        #1;
        areset = 1;
        expected = 0;
        #1;
        check(0);
        @(negedge clk);
        areset = 0;
        // Test every input combination from each known state.
        for (integer state_value = 0; state_value < 2; state_value++) begin
            for (integer combo = 0; combo < 4; combo++) begin
                step(0, 1); // Force OFF from either state.
                if (state_value == 1) step(1, 0);
                step((combo >> 1) & 1, combo & 1);
            end
        end
        step(1, 0);
        // Assert reset between clock edges while ON.
        #1;
        areset = 1;
        expected = 0;
        #1;
        check(0);
        j = 1;
        k = 0;
        @(posedge clk);
        #1;
        check(0);
        @(negedge clk);
        areset = 0;
        #1;
        check(0);
        @(posedge clk);
        expected = 1;
        #1;
        check(1);
        repeat (8) step(1, 1);
        $display("PASS: %0d checks", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Testbench timeout");
    end
endmodule
