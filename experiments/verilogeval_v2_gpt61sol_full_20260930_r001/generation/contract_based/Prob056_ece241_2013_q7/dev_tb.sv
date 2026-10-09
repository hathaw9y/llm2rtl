`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic j = 0;
    logic k = 0;
    wire Q;
    logic expected;
    integer checks = 0;
    integer state_index;
    integer combination;
    integer iteration;
    TopModule dut (.clk(clk), .j(j), .k(k), .Q(Q));

    task automatic check_q;
        begin
            checks = checks + 1;
            if (Q !== expected)
                $fatal(1, "FAIL check=%0d j=%b k=%b expected=%b Q=%b", checks, j, k, expected, Q);
        end
    endtask

    task automatic step(input logic new_j, input logic new_k);
        begin
            j = new_j;
            k = new_k;
            #2;
            check_q();
            if (!new_j && new_k) expected = 1'b0;
            else if (new_j && !new_k) expected = 1'b1;
            else if (new_j && new_k) expected = !expected;
            clk = 1'b1;
            #2;
            check_q();
            clk = 1'b0;
            #2;
            check_q();
        end
    endtask

    initial begin
        // Establish a known state solely through the specified clear operation.
        j = 0;
        k = 1;
        #2;
        clk = 1;
        expected = 0;
        #2;
        check_q();
        clk = 0;
        #2;
        check_q();
        for (state_index = 0; state_index < 2; state_index = state_index + 1)
            for (combination = 0; combination < 4; combination = combination + 1) begin
                if (state_index == 0) step(0, 1);
                else step(1, 0);
                step(combination[1], combination[0]);
            end
        for (iteration = 0; iteration < 16; iteration = iteration + 1)
            step(1, 1);
        for (iteration = 0; iteration < 256; iteration = iteration + 1)
            step(((iteration * 13 + iteration / 4) % 7) < 3,
                 ((iteration * 5 + iteration / 3) % 11) < 5);
        $display("PASS: %0d state and timing checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
