`timescale 1ns/1ps
module dev_tb;
    logic [2:0] a;
    wire [15:0] q;
    logic [15:0] expected [0:7];
    integer i, j;
    integer checks = 0;
    TopModule dut (.a(a), .q(q));

    task automatic check(input logic [15:0] want);
        begin
            #0; // Sample after combinational evaluation at this timestamp.
            if (q !== want)
                $fatal(1, "time=%0t a=%b expected=%h actual=%h", $time, a, want, q);
            checks = checks + 1;
        end
    endtask

    initial begin
        #300;
        $fatal(1, "Timeout");
    end

    initial begin
        expected[0] = 16'h1232;
        expected[1] = 16'haee0;
        expected[2] = 16'h27d4;
        expected[3] = 16'h5a0e;
        expected[4] = 16'h2066;
        expected[5] = 16'h64ce;
        expected[6] = 16'hc526;
        expected[7] = 16'h2f19;
        a = 3'bxxx; check(16'hxxxx); // 0 ns
        #5; check(16'hxxxx);         // 5 ns
        #5; check(16'hxxxx);         // 10 ns
        #5; a = 3'd0; check(16'h1232); // 15 ns
        #5; a = 3'd1; check(16'haee0);
        #5; a = 3'd2; check(16'h27d4);
        #5; a = 3'd3; check(16'h5a0e);
        #5; a = 3'd4; check(16'h2066);
        #5; a = 3'd5; check(16'h64ce);
        #5; a = 3'd6; check(16'hc526);
        #5; a = 3'd7; check(16'h2f19); // 50 ns
        #5; a = 3'd0; check(16'h1232);
        #5; a = 3'd1; check(16'haee0);
        #5; a = 3'd2; check(16'h27d4);
        #5; a = 3'd4; check(16'h2066);
        #5; a = 3'd1; check(16'haee0);
        #5; a = 3'd1; check(16'haee0);
        #5; a = 3'd3; check(16'h5a0e);
        #5; a = 3'd5; check(16'h64ce); // 90 ns
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                #1; a = i[2:0]; check(expected[i]);
                #1; a = j[2:0]; check(expected[j]);
            end
        end
        $display("PASS: %0d combinational lookup checks", checks);
        $finish;
    end
endmodule
