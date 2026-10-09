`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire q;
    // Bit index is the binary value of {a,b,c,d}, from original waveform.
    localparam logic [15:0] EXPECTED = 16'b1111110011111100;
    integer i;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .q(q));
    task automatic check(input integer index);
        begin
            {a,b,c,d} = index[3:0];
            #1;
            if (q !== EXPECTED[index])
                $fatal(1, "FAIL input=%04b expected=%b actual=%b", {a,b,c,d}, EXPECTED[index], q);
            checks = checks + 1;
        end
    endtask
    initial begin
        for (i = 0; i < 16; i = i + 1) check(i);
        for (i = 15; i >= 0; i = i - 1) check(i);
        $display("PASS: %0d truth-table checks, all 16 combinations in both orders", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
