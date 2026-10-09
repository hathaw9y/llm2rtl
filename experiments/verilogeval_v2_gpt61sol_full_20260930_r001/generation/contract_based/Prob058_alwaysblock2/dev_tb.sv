`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic a = 0;
    logic b = 0;
    wire out_assign, out_always_comb, out_always_ff;
    logic expected_ff;
    integer checks = 0;
    TopModule dut (.*);

    task automatic check_outputs;
        logic expected_comb;
        begin
            expected_comb = (a != b);
            if (out_assign !== expected_comb || out_always_comb !== expected_comb)
                $fatal(1, "Combinational mismatch a=%b b=%b", a, b);
            if (out_always_ff !== expected_ff)
                $fatal(1, "Registered mismatch expected=%b got=%b", expected_ff, out_always_ff);
            checks = checks + 1;
        end
    endtask

    initial begin
        #2;
        expected_ff = 0;
        clk = 1;
        #1;
        check_outputs();
        clk = 0;
        #1;
        for (integer source = 0; source < 4; source = source + 1) begin
            for (integer target = 0; target < 4; target = target + 1) begin
                a = source[1]; b = source[0];
                #1; check_outputs();
                expected_ff = (a != b);
                clk = 1;
                #1; check_outputs();
                a = target[1]; b = target[0];
                #1; check_outputs();
                clk = 0;
                #1; check_outputs();
                expected_ff = (a != b);
                clk = 1;
                #1; check_outputs();
                clk = 0;
                #1; check_outputs();
            end
        end
        $display("PASS: %0d output checks, all binary pairs and all 16 transitions", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Testbench timeout");
    end
endmodule
