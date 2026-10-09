`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg j = 0;
    reg k = 0;
    wire out;
    reg expected;
    integer checks = 0;
    integer s, combo, n;
    TopModule dut (.clk(clk), .areset(areset), .j(j), .k(k), .out(out));

    task verify;
        begin
            checks = checks + 1;
            if (out !== expected)
                $fatal(1, "Mismatch at t=%0t: out=%b expected=%b reset=%b j=%b k=%b", $time, out, expected, areset, j, k);
        end
    endtask

    task cycle(input reg ji, input reg ki);
        begin
            // Input changes and falling edges must not change the Moore state.
            j = ji; k = ki;
            #2; verify;
            if (areset) expected = 0;
            else if (expected == 0) begin
                if (ji == 1) expected = 1;
            end else begin
                if (ki == 1) expected = 0;
            end
            clk = 1;
            #1; verify;
            clk = 0;
            #1; verify;
        end
    endtask

    task reset_between_edges;
        begin
            #1; areset = 1; expected = 0;
            #1; verify;
            cycle(1, 0);
            cycle(1, 1);
            areset = 0;
            #1; verify;
        end
    endtask

    initial begin
        // The original specification has no required power-up state.
        reset_between_edges;
        for (s = 0; s < 2; s = s + 1) begin
            for (combo = 0; combo < 4; combo = combo + 1) begin
                reset_between_edges;
                if (s == 1) cycle(1, 0);
                cycle((combo >> 1) & 1, combo & 1);
            end
        end
        // Reset directly from ON with the clock already high, no new clock edge.
        cycle(1, 0);
        clk = 1;
        #1; verify;
        areset = 1; expected = 0;
        #1; verify;
        areset = 0;
        #1; verify;
        clk = 0;
        #1; verify;
        // Exercise sustained states and repeated OFF/ON toggling.
        for (n = 0; n < 16; n = n + 1) begin
            cycle(0, 0);
            cycle(1, 0);
            cycle(0, 0);
            cycle(1, 1);
            cycle(1, 1);
            cycle(0, 1);
        end
        $display("PASS: Moore FSM and asynchronous reset checks (%0d assertions)", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
