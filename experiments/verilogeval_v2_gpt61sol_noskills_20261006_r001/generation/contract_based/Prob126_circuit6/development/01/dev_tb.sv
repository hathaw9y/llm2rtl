`timescale 1ns/1ps
module dev_tb;
    reg [2:0] a;
    wire [15:0] q;
    reg [15:0] expected [0:7];
    integer i, j;
    integer checks = 0;
    TopModule dut (.a(a), .q(q));

    task check(input [15:0] value);
        begin
            if (q !== value)
                $fatal(1, "time=%0t a=%b expected=%h actual=%h", $time, a, value, q);
            checks = checks + 1;
        end
    endtask

    task waveform_step(input [2:0] value, input [15:0] result);
        begin
            #5;
            a = value;
            #0;
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
        a = 3'bxxx;
        #0; check(16'hxxxx);  // 0 ns
        waveform_step(3'bxxx, 16'hxxxx); // 5 ns
        waveform_step(3'bxxx, 16'hxxxx); // 10 ns
        waveform_step(3'd0, 16'h1232);   // 15 ns
        waveform_step(3'd1, 16'haee0);
        waveform_step(3'd2, 16'h27d4);
        waveform_step(3'd3, 16'h5a0e);
        waveform_step(3'd4, 16'h2066);
        waveform_step(3'd5, 16'h64ce);
        waveform_step(3'd6, 16'hc526);
        waveform_step(3'd7, 16'h2f19);   // 50 ns
        waveform_step(3'd0, 16'h1232);
        waveform_step(3'd1, 16'haee0);
        waveform_step(3'd2, 16'h27d4);
        waveform_step(3'd4, 16'h2066);
        waveform_step(3'd1, 16'haee0);
        waveform_step(3'd1, 16'haee0);
        waveform_step(3'd3, 16'h5a0e);
        waveform_step(3'd5, 16'h64ce);   // 90 ns

        // Exercise every binary source/destination transition without a clock.
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                #1; a = i; #0; check(expected[i]);
                #1; a = j; #0; check(expected[j]);
            end
        end
        #1; a = 3'bxxx; #0; check(16'hxxxx);
        #1; a = 3'd7; #0; check(16'h2f19);
        $display("PASS: original waveform and exhaustive transitions (%0d checks)", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
