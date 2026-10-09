`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg j = 0;
    reg k = 0;
    wire Q;
    reg expected = 1'bx;
    integer checks = 0;
    integer state_index, pair_index, repeat_index;

    TopModule dut (.clk(clk), .j(j), .k(k), .Q(Q));

    task check_output;
        begin
            checks = checks + 1;
            if (Q !== expected)
                $fatal(1, "Q mismatch at time %0t: j=%b k=%b expected=%b actual=%b", $time, j, k, expected, Q);
        end
    endtask

    task cycle(input reg next_j, input reg next_k);
        reg before_edge;
        begin
            before_edge = expected;
            j = next_j;
            k = next_k;
            #2;
            check_output();
            // The oracle is the original truth table, using pre-edge state.
            if (next_j == 0 && next_k == 0) expected = before_edge;
            else if (next_j == 0 && next_k == 1) expected = 0;
            else if (next_j == 1 && next_k == 0) expected = 1;
            else expected = ~before_edge;
            clk = 1;
            #1;
            check_output();
            // Input changes during the high phase cannot update Q.
            j = ~next_j;
            k = ~next_k;
            #1;
            check_output();
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        #1;
        check_output();
        cycle(0, 0);
        cycle(1, 1);
        cycle(0, 1);
        cycle(1, 0);
        // Exercise every truth-table row from each known pre-edge state.
        for (state_index = 0; state_index < 2; state_index = state_index + 1) begin
            for (pair_index = 0; pair_index < 4; pair_index = pair_index + 1) begin
                if (state_index == 0) cycle(0, 1);
                else cycle(1, 0);
                cycle((pair_index >> 1) & 1, pair_index & 1);
            end
        end
        for (repeat_index = 0; repeat_index < 16; repeat_index = repeat_index + 1)
            cycle(1, 1);
        for (repeat_index = 0; repeat_index < 8; repeat_index = repeat_index + 1)
            cycle(0, 0);
        cycle(0, 1);
        cycle(0, 1);
        cycle(1, 0);
        cycle(1, 0);
        $display("PASS: JK truth table and edge retention, %0d checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
