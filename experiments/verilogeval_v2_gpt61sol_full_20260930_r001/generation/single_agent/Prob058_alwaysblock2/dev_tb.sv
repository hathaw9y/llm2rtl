`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic a = 0;
    logic b = 0;
    wire out_assign, out_always_comb, out_always_ff;
    logic expected_ff;
    TopModule dut (.*);

    task automatic check_comb;
        if (out_assign !== (a ^ b) || out_always_comb !== (a ^ b))
            $fatal(1, "Combinational XOR mismatch");
    endtask

    initial begin
        #1;
        check_comb();
        if (out_always_ff !== 1'bx)
            $fatal(1, "Unexpected initialized sequential output");
        for (integer prior = 0; prior < 4; prior = prior + 1) begin
            for (integer next_pair = 0; next_pair < 4; next_pair = next_pair + 1) begin
                clk = 0;
                {a,b} = prior[1:0];
                #1;
                check_comb();
                clk = 1;
                expected_ff = a ^ b;
                #1;
                if (out_always_ff !== expected_ff)
                    $fatal(1, "Rising edge capture mismatch");
                {a,b} = next_pair[1:0];
                #1;
                check_comb();
                if (out_always_ff !== expected_ff)
                    $fatal(1, "Output changed between rising edges");
                clk = 0;
                #1;
                if (out_always_ff !== expected_ff)
                    $fatal(1, "Output changed on falling edge");
                clk = 1;
                expected_ff = a ^ b;
                #1;
                if (out_always_ff !== expected_ff)
                    $fatal(1, "Next rising edge capture mismatch");
            end
        end
        $display("PASS: all XOR combinations and sequential capture/hold checks");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Testbench timeout");
    end
endmodule
