`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic j = 0;
    logic k = 0;
    wire out;
    logic expected;
    integer checks = 0;
    integer s, inputs, n;
    TopModule dut (.clk(clk), .areset(areset), .j(j), .k(k), .out(out));
    always #5 clk = ~clk;

    task automatic check_output;
        begin
            if (out !== expected)
                $fatal(1, "Mismatch at %0t: out=%b expected=%b j=%b k=%b reset=%b", $time, out, expected, j, k, areset);
            checks = checks + 1;
        end
    endtask

    // Inputs change after the falling edge; the Moore output must hold
    // until the next rising edge. The oracle is the stated transition table.
    task automatic step(input logic j_value, input logic k_value);
        begin
            @(negedge clk);
            j = j_value;
            k = k_value;
            #1;
            check_output();
            @(posedge clk);
            if (areset) expected = 0;
            else if (expected == 0) expected = j_value;
            else expected = !k_value;
            #1;
            check_output();
        end
    endtask

    task automatic reset_between_edges;
        begin
            @(negedge clk);
            #2;
            areset = 1;
            expected = 0;
            #1;
            check_output();
            @(posedge clk);
            #1;
            check_output();
            @(negedge clk);
            #1;
            areset = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        // No power-up value is specified, so begin checking after reset.
        expected = 0;
        reset_between_edges();
        for (s = 0; s < 2; s = s + 1) begin
            for (inputs = 0; inputs < 4; inputs = inputs + 1) begin
                reset_between_edges();
                if (s == 1) step(1, 0);
                step((inputs & 2) != 0, (inputs & 1) != 0);
            end
        end
        // j=k=1 must alternate states on successive clock edges.
        reset_between_edges();
        repeat (8) step(1, 1);
        step(1, 0);
        reset_between_edges();
        // Reset dominates both inputs while held through several clocks.
        @(negedge clk);
        #2;
        areset = 1;
        j = 1;
        k = 1;
        expected = 0;
        #1;
        check_output();
        repeat (3) step(1, 1);
        @(negedge clk);
        #1;
        areset = 0;
        #1;
        check_output();
        for (n = 0; n < 32; n = n + 1)
            step((n % 3) != 0, (n % 5) < 2);
        $display("PASS: %0d FSM checks", checks);
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Timeout");
    end
endmodule
