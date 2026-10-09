`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    logic q;
    // Indexed by the binary input tuple {a,b,c,d}; transcribed from the problem.
    localparam logic [15:0] EXPECTED = 16'b1110_1110_1110_0000;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .q(q));
    initial begin
        for (int i = 0; i < 16; i++) begin
            {a,b,c,d} = 4'(i);
            #1;
            if (q !== EXPECTED[i])
                $fatal(1, "FAIL input=%04b expected=%b actual=%b", {a,b,c,d}, EXPECTED[i], q);
        end
        $display("PASS: all 16 input combinations match the supplied waveform");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
