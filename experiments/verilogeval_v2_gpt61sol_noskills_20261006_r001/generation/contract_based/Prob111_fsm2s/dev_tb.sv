`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg j = 0;
    reg k = 0;
    wire out;
    reg expected;
    reg valid = 0;
    integer checks = 0;
    integer s, pair, n;
    TopModule dut(.clk(clk), .reset(reset), .j(j), .k(k), .out(out));

    task verify;
        begin
            if (valid) begin
                if (out !== expected)
                    $fatal(1, "Mismatch t=%0t reset=%b j=%b k=%b expected=%b got=%b", $time, reset, j, k, expected, out);
                checks = checks + 1;
            end
        end
    endtask

    // Inputs change while clock is low. Check retention before the edge,
    // then apply the original transition table and check after NBA settles.
    task cycle(input reg r, input reg a, input reg b);
        begin
            clk = 0;
            reset = r; j = a; k = b;
            #2;
            verify;
            clk = 1;
            if (r) begin
                expected = 0;
                valid = 1;
            end else if (valid) begin
                case (expected)
                    1'b0: expected = a;
                    1'b1: expected = !b;
                endcase
            end
            #1;
            verify;
            clk = 0;
            #1;
            verify;
        end
    endtask

    initial begin
        // No expected power-up value is specified by the problem.
        cycle(1, 1, 1);
        for (s = 0; s < 2; s = s + 1) begin
            for (pair = 0; pair < 4; pair = pair + 1) begin
                cycle(1, 0, 0);
                if (s == 1) cycle(0, 1, 0);
                cycle(0, (pair >> 1) & 1, pair & 1);
            end
        end
        // Reset priority for every input combination in both states.
        for (s = 0; s < 2; s = s + 1) begin
            for (pair = 0; pair < 4; pair = pair + 1) begin
                cycle(1, 0, 0);
                if (s == 1) cycle(0, 1, 0);
                cycle(1, (pair >> 1) & 1, pair & 1);
            end
        end
        cycle(0, 1, 0); // ON
        // A reset pulse wholly between rising edges must not reset ON.
        reset = 1; j = 0; k = 1;
        #1; verify;
        reset = 0;
        #1; verify;
        cycle(0, 0, 0);
        // Reset assertion while clock is high also waits for the next edge.
        clk = 1;
        expected = 1;
        #1; verify;
        reset = 1;
        #1; verify;
        clk = 0;
        #1; verify;
        cycle(1, 1, 0);
        for (n = 0; n < 8; n = n + 1) cycle(0, 0, n & 1);
        cycle(0, 1, 0);
        for (n = 0; n < 8; n = n + 1) cycle(0, n & 1, 0);
        for (n = 0; n < 16; n = n + 1) cycle(0, 1, 1);
        $display("PASS: original FSM transitions, reset priority, and edge retention (%0d checks)", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
