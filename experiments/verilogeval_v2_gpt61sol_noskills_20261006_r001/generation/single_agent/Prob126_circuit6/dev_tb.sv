`timescale 1ns/1ps
module dev_tb;
    reg [2:0] a;
    wire [15:0] q;
    reg [15:0] expected [0:7];
    integer src, dst;
    TopModule dut (.a(a), .q(q));

    task check(input [15:0] value);
        begin
            #0;
            if (q !== value)
                $fatal(1, "At %0t a=%b expected=%h got=%h", $time, a, value, q);
        end
    endtask
    task sample(input [2:0] value, input [15:0] result);
        begin
            a = value;
            check(result);
        end
    endtask

    initial begin
        expected[0] = 16'h1232;
        expected[1] = 16'haee0;
        expected[2] = 16'h27d4;
        expected[3] = 16'h5a0e;
        expected[4] = 16'h2066;
        expected[5] = 16'h64ce;
        expected[6] = 16'hc526;
        expected[7] = 16'h2f19;
        // Replay every sample at the original timestamp, settling only delta cycles.
        a = 3'bxxx;
        check(16'hxxxx);                      // 0 ns
        #5; check(16'hxxxx);                  // 5 ns
        #5; check(16'hxxxx);                  // 10 ns
        #5; sample(3'd0, 16'h1232);           // 15 ns
        #5; sample(3'd1, 16'haee0);           // 20 ns
        #5; sample(3'd2, 16'h27d4);           // 25 ns
        #5; sample(3'd3, 16'h5a0e);           // 30 ns
        #5; sample(3'd4, 16'h2066);           // 35 ns
        #5; sample(3'd5, 16'h64ce);           // 40 ns
        #5; sample(3'd6, 16'hc526);           // 45 ns
        #5; sample(3'd7, 16'h2f19);           // 50 ns
        #5; sample(3'd0, 16'h1232);           // 55 ns
        #5; sample(3'd1, 16'haee0);           // 60 ns
        #5; sample(3'd2, 16'h27d4);           // 65 ns
        #5; sample(3'd4, 16'h2066);           // 70 ns
        #5; sample(3'd1, 16'haee0);           // 75 ns
        #5; sample(3'd1, 16'haee0);           // 80 ns
        #5; sample(3'd3, 16'h5a0e);           // 85 ns
        #5; sample(3'd5, 16'h64ce);           // 90 ns
        // Exercise all known-input transitions, including unchanged inputs.
        for (src = 0; src < 8; src = src + 1)
            for (dst = 0; dst < 8; dst = dst + 1) begin
                #1; sample(src[2:0], expected[src]);
                #1; sample(dst[2:0], expected[dst]);
            end
        $display("PASS: original waveform and all 64 known-input transitions");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
