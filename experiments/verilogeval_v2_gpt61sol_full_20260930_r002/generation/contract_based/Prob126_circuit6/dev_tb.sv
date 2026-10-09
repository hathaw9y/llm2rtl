`timescale 1ns/1ps
module dev_tb;
    logic [2:0] a;
    wire [15:0] q;
    logic [15:0] expected [0:7];
    integer i, j;
    integer checks = 0;
    TopModule dut (.a(a), .q(q));

    task automatic check(input logic [15:0] value);
        begin
            if (q !== value)
                $fatal(1, "Mismatch at %0t: a=%b q=%h expected=%h", $time, a, q, value);
            checks = checks + 1;
        end
    endtask

    // A zero-time scheduling phase lets combinational logic settle without
    // moving any original waveform stimulus or observation timestamp.
    task automatic drive_check(input logic [2:0] index, input logic [15:0] value);
        begin
            a = index;
            #0;
            check(value);
        end
    endtask

    initial begin
        #200;
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
        a = 3'bxxx;
        #0; check(16'hxxxx);
        #5; check(16'hxxxx);
        #5; check(16'hxxxx);
        #5; drive_check(3'd0, 16'h1232);
        #5; drive_check(3'd1, 16'haee0);
        #5; drive_check(3'd2, 16'h27d4);
        #5; drive_check(3'd3, 16'h5a0e);
        #5; drive_check(3'd4, 16'h2066);
        #5; drive_check(3'd5, 16'h64ce);
        #5; drive_check(3'd6, 16'hc526);
        #5; drive_check(3'd7, 16'h2f19);
        #5; drive_check(3'd0, 16'h1232);
        #5; drive_check(3'd1, 16'haee0);
        #5; drive_check(3'd2, 16'h27d4);
        #5; drive_check(3'd4, 16'h2066);
        #5; drive_check(3'd1, 16'haee0);
        #5; drive_check(3'd1, 16'haee0);
        #5; drive_check(3'd3, 16'h5a0e);
        #5; drive_check(3'd5, 16'h64ce);
        // Exercise every predecessor/current pair to detect unintended state.
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                #0.5; drive_check(i[2:0], expected[i]);
                #0.5; drive_check(j[2:0], expected[j]);
            end
        end
        $display("PASS: original waveform and all known-input transitions (%0d checks)", checks);
        $finish;
    end
endmodule
