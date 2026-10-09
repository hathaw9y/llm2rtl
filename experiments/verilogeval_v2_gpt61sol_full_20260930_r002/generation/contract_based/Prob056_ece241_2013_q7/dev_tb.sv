`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic j = 1'b0;
    logic k = 1'b0;
    wire Q;
    logic expected = 1'bx;
    integer checks = 0;
    integer state_index;
    integer pair_index;
    integer repeat_index;
    TopModule dut (.clk(clk), .j(j), .k(k), .Q(Q));

    task automatic compare;
        begin
            checks = checks + 1;
            if (Q !== expected)
                $fatal(1, "Q mismatch time=%0t j=%b k=%b expected=%b actual=%b", $time,j,k,expected,Q);
        end
    endtask

    task automatic cycle(input logic next_j, input logic next_k);
        begin
            // Inputs change with clock low: they must not affect Q yet.
            j = next_j;
            k = next_k;
            #2;
            compare();
            // Model the original table via independent set/reset conditions.
            if (next_j && !next_k)
                expected = 1'b1;
            else if (!next_j && next_k)
                expected = 1'b0;
            else if (next_j && next_k)
                expected = ~expected;
            clk = 1'b1;
            #1; // Observe after nonblocking assignments settle.
            compare();
            // Exercise input mutation during the high phase as well.
            j = ~next_j;
            k = ~next_k;
            #2;
            compare();
            clk = 1'b0;
            #1;
            compare();
        end
    endtask

    initial begin
        #1;
        compare();
        cycle(0,0); // Unknown state must hold.
        cycle(1,1); // Complementing unknown remains unknown.
        cycle(0,1); // Clear resolves unknown.
        for (state_index = 0; state_index < 2; state_index = state_index + 1) begin
            for (pair_index = 0; pair_index < 4; pair_index = pair_index + 1) begin
                if (state_index == 0) cycle(0,1);
                else cycle(1,0);
                cycle((pair_index >> 1) & 1, pair_index & 1);
            end
        end
        for (repeat_index = 0; repeat_index < 16; repeat_index = repeat_index + 1) begin
            cycle(1,1);
            cycle(0,0);
        end
        cycle(1,0);
        cycle(1,0);
        cycle(0,1);
        cycle(0,1);
        $display("PASS JK truth table and edge stability: %0d comparisons", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
