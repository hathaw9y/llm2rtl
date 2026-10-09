`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire q;
    localparam logic [15:0] EXPECTED = 16'b1001011001101001;
    integer checks = 0;
    integer i, j;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .q(q));

    task automatic check_input(input logic [3:0] stimulus);
        begin
            {a,b,c,d} = stimulus;
            #1;
            if (q !== EXPECTED[stimulus])
                $fatal(1, "FAIL input=%b q=%b expected=%b", stimulus, q, EXPECTED[stimulus]);
            checks = checks + 1;
        end
    endtask

    initial begin
        repeat (4) check_input(4'b0000);
        for (i = 0; i < 16; i = i + 1) check_input(i[3:0]);
        for (i = 15; i >= 0; i = i - 1) check_input(i[3:0]);
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1) begin
                check_input(i[3:0]);
                check_input(j[3:0]);
            end
        $display("PASS: %0d checks, all binary inputs and all 256 ordered transitions", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
