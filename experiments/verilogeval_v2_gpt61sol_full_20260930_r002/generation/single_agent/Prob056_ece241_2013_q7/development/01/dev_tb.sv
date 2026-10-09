`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic j = 0;
    logic k = 0;
    wire Q;
    logic expected = 1'bx;
    integer checks = 0;
    integer old_state;
    integer operation;
    TopModule dut (.clk(clk), .j(j), .k(k), .Q(Q));

    task automatic check_q;
        begin
            if (Q !== expected)
                $fatal(1, "Q mismatch: j=%b k=%b clk=%b expected=%b actual=%b", j, k, clk, expected, Q);
            checks = checks + 1;
        end
    endtask

    task automatic cycle(input logic new_j, input logic new_k);
        begin
            j = new_j;
            k = new_k;
            #2;
            check_q(); // Input changes alone must not update the register.
            clk = 1;
            // Independent truth-table oracle, evaluated from the previous Q.
            if (!new_j && new_k) expected = 1'b0;
            else if (new_j && !new_k) expected = 1'b1;
            else if (new_j && new_k) expected = ~expected;
            #1;
            check_q(); // Sample after nonblocking assignments have settled.
            j = ~new_j;
            k = ~new_k;
            #2;
            check_q(); // No asynchronous update while clock is high.
            clk = 0;
            #1;
            check_q(); // Falling edges must preserve Q.
        end
    endtask

    initial begin
        #1;
        check_q();
        cycle(0, 0); // Uninitialized storage holds X.
        cycle(1, 1); // Toggling an unknown state remains unknown.
        for (old_state = 0; old_state < 2; old_state = old_state + 1) begin
            for (operation = 0; operation < 4; operation = operation + 1) begin
                if (old_state == 0) cycle(0, 1);
                else cycle(1, 0);
                cycle((operation >> 1) & 1, operation & 1);
            end
        end
        repeat (16) cycle(1, 1);
        repeat (4) cycle(0, 0);
        $display("PASS JK flip-flop: %0d comparisons", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
