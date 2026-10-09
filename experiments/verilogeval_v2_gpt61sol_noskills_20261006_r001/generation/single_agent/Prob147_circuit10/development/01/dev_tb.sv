`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg a = 1;
    reg b = 1'bx;
    wire q, state;
    integer checks = 0;
    TopModule dut (.clk(clk), .a(a), .b(b), .q(q), .state(state));

    task row(input integer t, input reg c, aa, bb, ss, qq);
        begin
            #(t - $realtime);
            // Clock samples the inputs from the preceding waveform interval.
            // New input values settle at the same timestamp, after sampling.
            clk = c;
            a <= aa;
            b <= bb;
            #0.001;
            if (state !== ss || q !== qq)
                $fatal(1, "waveform t=%0d: state=%b q=%b expected %b %b", t, state, q, ss, qq);
            checks = checks + 1;
        end
    endtask

    // Independently enumerated combinational truth table.
    task truth(input reg s, aa, bb, input reg expected);
        begin
            clk = 0;
            a = s;
            b = s;
            #1; clk = 1;
            #0.001;
            if (state !== s) $fatal(1, "state setup failed");
            #0.999; clk = 0;
            a = aa; b = bb;
            #1;
            if (state !== s || q !== expected)
                $fatal(1, "truth table state=%b a=%b b=%b q=%b expected=%b", s, aa, bb, q, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        row(0,0,1,1'bx,1'bx,1'bx);
        row(5,1,1,1'bx,1'bx,1'bx);
        row(10,0,0,0,1'bx,1'bx);
        row(15,1,0,0,0,0);
        row(20,0,0,0,0,0);
        row(25,1,0,0,0,0);
        row(30,0,0,0,0,0);
        row(35,1,0,0,0,0);
        row(40,0,0,0,0,0);
        row(45,1,0,1,0,1);
        row(50,0,0,1,0,1);
        row(55,1,1,0,0,1);
        row(60,0,1,0,0,1);
        row(65,1,1,1,0,0);
        row(70,0,1,1,0,0);
        row(75,1,0,0,1,1);
        row(80,0,0,0,1,1);
        row(85,1,1,1,0,0);
        row(90,0,1,1,0,0);
        row(95,1,1,1,1,1);
        row(100,0,1,1,1,1);
        row(105,1,1,1,1,1);
        row(110,0,1,1,1,1);
        row(115,1,1,0,1,0);
        row(120,0,1,0,1,0);
        row(125,1,0,1,1,0);
        row(130,0,0,1,1,0);
        row(135,1,0,0,1,1);
        row(140,0,0,0,1,1);
        row(145,1,0,0,0,0);
        row(150,0,0,0,0,0);
        row(155,1,0,0,0,0);
        row(160,0,0,0,0,0);
        row(165,1,0,0,0,0);
        row(170,0,0,0,0,0);
        row(175,1,0,0,0,0);
        row(180,0,0,0,0,0);
        row(185,1,0,0,0,0);
        row(190,0,0,0,0,0);
        truth(0,0,0,0);
        truth(0,0,1,1);
        truth(0,1,0,1);
        truth(0,1,1,0);
        truth(1,0,0,1);
        truth(1,0,1,0);
        truth(1,1,0,0);
        truth(1,1,1,1);
        $display("PASS waveform and directed truth table: %0d checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "timeout");
    end
endmodule
