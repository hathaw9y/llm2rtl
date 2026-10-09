`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic j = 0;
    logic k = 0;
    wire out;
    bit expected = 0;
    integer checks = 0;
    integer s, combo, n;
    TopModule dut (.clk(clk), .areset(areset), .j(j), .k(k), .out(out));

    task automatic check_output;
        begin
            checks = checks + 1;
            if (out !== expected)
                $fatal(1, "Mismatch check=%0d expected=%b actual=%b", checks, expected, out);
        end
    endtask

    task automatic tick;
        begin
            #2;
            if (areset) expected = 0;
            else if (expected) expected = !k;
            else expected = j;
            clk = 1;
            #1;
            check_output();
            clk = 0;
            #1;
        end
    endtask

    task automatic reset_async;
        begin
            #1;
            areset = 1;
            expected = 0;
            #1;
            check_output();
            tick();
            areset = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        reset_async();
        for (s = 0; s < 2; s = s + 1) begin
            for (combo = 0; combo < 4; combo = combo + 1) begin
                reset_async();
                if (s == 1) begin
                    j = 1; k = 0;
                    tick();
                end
                j = (combo >> 1) & 1;
                k = combo & 1;
                #1;
                check_output();
                tick();
            end
        end
        j = 1; k = 0;
        reset_async();
        tick();
        reset_async();
        for (n = 0; n < 64; n = n + 1) begin
            j = ((n * 5 + n / 4) % 3) != 0;
            k = ((n * 3 + n / 7) % 5) < 2;
            #1;
            check_output();
            tick();
            if ((n % 13) == 0) reset_async();
        end
        $display("PASS: %0d output checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Testbench timeout");
    end
endmodule
