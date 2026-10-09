`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg L = 0;
    reg q_in = 0;
    reg r_in = 0;
    wire Q;
    reg expected;
    integer i;
    integer checks = 0;

    TopModule dut (.clk(clk), .L(L), .q_in(q_in), .r_in(r_in), .Q(Q));

    task check_output;
        begin
            if (Q !== expected)
                $fatal(1, "Mismatch at %0t: L=%b q_in=%b r_in=%b Q=%b expected=%b",
                       $time, L, q_in, r_in, Q, expected);
            checks = checks + 1;
        end
    endtask

    task cycle(input reg select_load, input reg feedback, input reg load_data);
        reg next_expected;
        begin
            L = select_load;
            q_in = feedback;
            r_in = load_data;
            #2;
            check_output();
            // Independent oracle: the full_module's procedural if selects the
            // load path only when L is true; otherwise use the feedback path.
            if (select_load)
                next_expected = load_data;
            else
                next_expected = feedback;
            clk = 1;
            #1;
            expected = next_expected;
            check_output();
            // Alter both data paths while the clock is high.
            q_in = ~feedback;
            r_in = ~load_data;
            L = ~select_load;
            #2;
            check_output();
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        expected = 1'bx;
        #1;
        check_output();
        // Exhaust all binary mux inputs, then repeat in reverse order.
        for (i = 0; i < 8; i = i + 1)
            cycle((i >> 2) & 1, (i >> 1) & 1, i & 1);
        for (i = 7; i >= 0; i = i - 1)
            cycle((i >> 2) & 1, (i >> 1) & 1, i & 1);
        // Unknown selected data propagates, while unselected data is ignored.
        cycle(1'b1, 1'bx, 1'b0);
        cycle(1'b0, 1'b1, 1'bx);
        cycle(1'b1, 1'b0, 1'bx);
        cycle(1'b0, 1'bx, 1'b1);
        // Preserve the original procedural if behavior for unknown L.
        cycle(1'bx, 1'b0, 1'b1);
        cycle(1'bz, 1'b1, 1'b0);
        cycle(1'b1, 1'b0, 1'b1);
        $display("PASS: %0d mux/flip-flop checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
