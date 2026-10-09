`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire q;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .q(q));

    task automatic sample(input logic [3:0] inputs, input logic expected);
        begin
            {a, b, c, d} = inputs;
            // Settle zero-delay combinational logic at the original timestamp.
            #0;
            if (q !== expected)
                $fatal(1, "time=%0t inputs=%b expected=%b actual=%b", $time, inputs, expected, q);
            checks = checks + 1;
        end
    endtask

    initial begin
        sample(4'b0000, 1'b1);       // 0 ns
        #5 sample(4'b0000, 1'b1);    // 5 ns
        #5 sample(4'b0000, 1'b1);    // 10 ns
        #5 sample(4'b0000, 1'b1);    // 15 ns
        #5 sample(4'b0001, 1'b0);    // 20 ns
        #5 sample(4'b0010, 1'b0);    // 25 ns
        #5 sample(4'b0011, 1'b1);    // 30 ns
        #5 sample(4'b0100, 1'b0);    // 35 ns
        #5 sample(4'b0101, 1'b1);    // 40 ns
        #5 sample(4'b0110, 1'b1);    // 45 ns
        #5 sample(4'b0111, 1'b0);    // 50 ns
        #5 sample(4'b1000, 1'b0);    // 55 ns
        #5 sample(4'b1001, 1'b1);    // 60 ns
        #5 sample(4'b1010, 1'b1);    // 65 ns
        #5 sample(4'b1011, 1'b0);    // 70 ns
        #5 sample(4'b1100, 1'b1);    // 75 ns
        #5 sample(4'b1101, 1'b0);    // 80 ns
        #5 sample(4'b1110, 1'b0);    // 85 ns
        #5 sample(4'b1111, 1'b1);    // 90 ns
        $display("PASS: %0d original waveform samples, all 16 input combinations", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
