`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire q;
    localparam logic [15:0] EXPECTED = 16'b1001011001101001;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .q(q));
    initial begin
        for (integer i = 0; i < 16; i = i + 1) begin
            {a, b, c, d} = i[3:0];
            #1;
            if (q !== EXPECTED[i])
                $fatal(1, "FAIL input=%04b expected=%b actual=%b", {a,b,c,d}, EXPECTED[i], q);
        end
        $display("PASS: all 16 waveform input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
