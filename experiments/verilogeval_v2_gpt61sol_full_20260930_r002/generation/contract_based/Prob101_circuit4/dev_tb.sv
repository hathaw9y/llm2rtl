`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire q;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .q(q));
    task automatic sample(input logic expected_q);
        begin
            #0.001;
            if (q !== expected_q)
                $fatal(1, "Mismatch at %0t: abcd=%b%b%b%b q=%b expected=%b", $time, a,b,c,d,q,expected_q);
            checks = checks + 1;
        end
    endtask
    initial begin
        #200;
        $fatal(1, "Timeout");
    end
    initial begin
        {a,b,c,d} = 4'b0000; sample(1'b0); // Original 0 ns
        #4.999;
        {a,b,c,d} = 4'b0000; sample(1'b0); // Original 5 ns
        #4.999;
        {a,b,c,d} = 4'b0000; sample(1'b0); // Original 10 ns
        #4.999;
        {a,b,c,d} = 4'b0000; sample(1'b0); // Original 15 ns
        #4.999;
        {a,b,c,d} = 4'b0001; sample(1'b0); // Original 20 ns
        #4.999;
        {a,b,c,d} = 4'b0010; sample(1'b1); // Original 25 ns
        #4.999;
        {a,b,c,d} = 4'b0011; sample(1'b1); // Original 30 ns
        #4.999;
        {a,b,c,d} = 4'b0100; sample(1'b1); // Original 35 ns
        #4.999;
        {a,b,c,d} = 4'b0101; sample(1'b1); // Original 40 ns
        #4.999;
        {a,b,c,d} = 4'b0110; sample(1'b1); // Original 45 ns
        #4.999;
        {a,b,c,d} = 4'b0111; sample(1'b1); // Original 50 ns
        #4.999;
        {a,b,c,d} = 4'b1000; sample(1'b0); // Original 55 ns
        #4.999;
        {a,b,c,d} = 4'b1001; sample(1'b0); // Original 60 ns
        #4.999;
        {a,b,c,d} = 4'b1010; sample(1'b1); // Original 65 ns
        #4.999;
        {a,b,c,d} = 4'b1011; sample(1'b1); // Original 70 ns
        #4.999;
        {a,b,c,d} = 4'b1100; sample(1'b1); // Original 75 ns
        #4.999;
        {a,b,c,d} = 4'b1101; sample(1'b1); // Original 80 ns
        #4.999;
        {a,b,c,d} = 4'b1110; sample(1'b1); // Original 85 ns
        #4.999;
        {a,b,c,d} = 4'b1111; sample(1'b1); // Original 90 ns
        #0.999; {a,b,c,d} = 4'b1111; sample(1'b1);
        #0.999; {a,b,c,d} = 4'b1110; sample(1'b1);
        #0.999; {a,b,c,d} = 4'b1101; sample(1'b1);
        #0.999; {a,b,c,d} = 4'b1100; sample(1'b1);
        #0.999; {a,b,c,d} = 4'b1011; sample(1'b1);
        #0.999; {a,b,c,d} = 4'b1010; sample(1'b1);
        #0.999; {a,b,c,d} = 4'b1001; sample(1'b0);
        #0.999; {a,b,c,d} = 4'b1000; sample(1'b0);
        #0.999; {a,b,c,d} = 4'b0111; sample(1'b1);
        #0.999; {a,b,c,d} = 4'b0110; sample(1'b1);
        #0.999; {a,b,c,d} = 4'b0101; sample(1'b1);
        #0.999; {a,b,c,d} = 4'b0100; sample(1'b1);
        #0.999; {a,b,c,d} = 4'b0011; sample(1'b1);
        #0.999; {a,b,c,d} = 4'b0010; sample(1'b1);
        #0.999; {a,b,c,d} = 4'b0001; sample(1'b0);
        #0.999; {a,b,c,d} = 4'b0000; sample(1'b0);
        $display("PASS: original waveform and reverse-order truth table, %0d checks", checks);
        $finish;
    end
endmodule
