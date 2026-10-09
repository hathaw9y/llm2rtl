`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    wire q;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .q(q));

    task automatic row(input logic av, input logic bv, input logic expected);
        begin
            a = av;
            b = bv;
            #0;
            if (q !== expected)
                $fatal(1, "Mismatch at %0t: a=%b b=%b q=%b expected=%b", $time, a, b, q, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        row(0, 0, 0);       // 0ns
        #5; row(0, 0, 0);  // 5ns
        #5; row(0, 0, 0);  // 10ns
        #5; row(0, 0, 0);  // 15ns
        #5; row(0, 0, 0);  // 20ns
        #5; row(0, 1, 0);  // 25ns
        #5; row(0, 1, 0);  // 30ns
        #5; row(1, 0, 0);  // 35ns
        #5; row(1, 0, 0);  // 40ns
        #5; row(1, 1, 1);  // 45ns
        #5; row(1, 1, 1);  // 50ns
        #5; row(0, 0, 0);  // 55ns
        #5; row(0, 0, 0);  // 60ns
        #5; row(0, 1, 0);  // 65ns
        #5; row(0, 1, 0);  // 70ns
        #5; row(1, 0, 0);  // 75ns
        #5; row(1, 0, 0);  // 80ns
        #5; row(1, 1, 1);  // 85ns
        #5; row(1, 1, 1);  // 90ns
        if (checks != 19) $fatal(1, "Incomplete waveform replay");
        $display("PASS: all 19 original waveform rows checked");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
