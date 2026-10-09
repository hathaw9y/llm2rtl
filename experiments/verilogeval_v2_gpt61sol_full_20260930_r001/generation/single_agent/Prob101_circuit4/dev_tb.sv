`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    logic q;
    localparam logic [15:0] EXPECTED = 16'hFCFC;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .q(q));
    initial begin
        for (integer i = 0; i < 16; i = i + 1) begin
            {a, b, c, d} = i[3:0];
            #1;
            if (q !== EXPECTED[i])
                $fatal(1, "FAIL inputs=%04b q=%b expected=%b", {a,b,c,d}, q, EXPECTED[i]);
        end
        $display("PASS: all 16 input combinations match the supplied waveform table");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
