`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire q;
    // Original waveform values indexed by {a,b,c,d}, from 0000 to 1111.
    localparam logic [15:0] EXPECTED = 16'b1110_1110_1110_0000;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .q(q));
    task automatic check_input(input integer index);
        begin
            {a,b,c,d} = index[3:0];
            #1;
            if (q !== EXPECTED[index])
                $fatal(1, "FAIL input=%04b expected=%b actual=%b", {a,b,c,d}, EXPECTED[index], q);
            checks = checks + 1;
        end
    endtask
    initial begin
        for (integer i = 0; i < 16; i = i + 1) check_input(i);
        for (integer i = 15; i >= 0; i = i - 1) check_input(i);
        check_input(0);
        check_input(0);
        $display("PASS: %0d checks; all 16 binary combinations in both orders", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
