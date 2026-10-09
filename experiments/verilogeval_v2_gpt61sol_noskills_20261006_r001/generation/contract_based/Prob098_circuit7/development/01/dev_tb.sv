`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg a = 1'bx;
    wire q;
    integer i;
    reg expected;
    TopModule dut (.clk(clk), .a(a), .q(q));
    always #5 clk = ~clk;

    task check(input reg value);
        begin
            if (q !== value)
                $fatal(1, "At %0t q=%b expected=%b", $time, q, value);
        end
    endtask

    // Coincident input changes take effect after the DUT samples that edge.
    initial begin
        #5 a <= 0;
        #30 a <= 1;
    end

    initial begin
        // Literal original waveform, at every listed timestamp after settling.
        for (i = 0; i <= 18; i = i + 1) begin
            if (i <= 2) expected = 1'bx;
            else if (i <= 8) expected = 1'b1;
            else expected = 1'b0;
            #0.001;
            check(expected);
            if (i < 18) #4.999;
        end
        // Changes away from edges establish the single-edge capture behavior.
        #0.999 a = 0; // 91 ns
        #1 check(0);
        #3.001 check(1); // after 95 ns positive edge
        #0.999 a = 1; // 96 ns
        #1 check(1);
        #3.001 check(1); // falling edge at 100 ns holds q
        #5 check(0); // rising edge at 105 ns
        #0.999 a = 1'bx; // 106 ns
        #1 check(0);
        #8.001 check(1'bx); // 115 ns
        #0.999 a = 1'bz; // 116 ns
        #9.001 check(1'bx); // 125 ns
        #0.999 a = 0; // 126 ns
        #9.001 check(1); // 135 ns
        #0.999 a = 1; // 136 ns
        #9.001 check(0); // 145 ns
        $display("PASS original waveform and directed edge/hold/unknown checks");
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
