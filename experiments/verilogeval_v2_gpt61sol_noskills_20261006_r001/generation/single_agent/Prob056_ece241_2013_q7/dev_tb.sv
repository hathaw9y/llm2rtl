`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg j = 0;
    reg k = 0;
    wire Q;
    reg expected = 1'bx;
    integer checks = 0;
    integer state_index;
    integer combo;
    TopModule dut (.clk(clk), .j(j), .k(k), .Q(Q));

    task check_output;
        begin
            if (Q !== expected)
                $fatal(1, "Mismatch at %0t: j=%b k=%b Q=%b expected=%b", $time, j, k, Q, expected);
            checks = checks + 1;
        end
    endtask

    task step(input reg next_j, input reg next_k);
        begin
            j = next_j;
            k = next_k;
            #2;
            check_output; // Input changes during low clock must not update Q.
            // Independent truth-table oracle, evaluated from old output state.
            if (!next_j && next_k) expected = 1'b0;
            else if (next_j && !next_k) expected = 1'b1;
            else if (next_j && next_k) expected = ~expected;
            clk = 1;
            #1;
            check_output; // Observe after nonblocking assignments settle.
            j = ~next_j;
            k = ~next_k;
            #1;
            check_output; // No response to input changes while clock is high.
            clk = 0;
            #1;
            check_output; // Falling edges do not update Q.
        end
    endtask

    initial begin
        #1;
        check_output;
        step(0, 0); // Uninitialized state remains unknown on hold.
        step(1, 1); // Toggle cannot resolve an unknown state.
        step(0, 1); // Clear establishes a known state without a reset port.
        for (state_index = 0; state_index < 2; state_index = state_index + 1) begin
            for (combo = 0; combo < 4; combo = combo + 1) begin
                if (state_index == 0) step(0, 1);
                else step(1, 0);
                step((combo >> 1) & 1, combo & 1);
            end
        end
        repeat (10) step(1, 1);
        step(0, 0);
        step(0, 0);
        $display("PASS JK flip-flop: %0d checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
