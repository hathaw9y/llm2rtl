`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic resetn = 1;
    logic [2:0] r = 0;
    wire [2:0] g;
    logic [2:0] expected = 0;
    bit initialized = 0;
    integer checks = 0;
    integer owner, mask, rst, k;
    TopModule dut (.clk(clk), .resetn(resetn), .r(r), .g(g));

    task automatic step(input logic rn, input logic [2:0] req);
        logic [2:0] next_grant;
        begin
            clk = 0;
            resetn = rn;
            r = req;
            #2;
            if (initialized && g !== expected)
                $fatal(1, "Output changed away from rising edge: g=%b expected=%b", g, expected);
            next_grant = expected;
            if (!rn) next_grant = 0;
            else if (expected == 0) begin
                next_grant = 0;
                for (integer i = 2; i >= 0; i = i - 1)
                    if (req[i]) next_grant = 3'b001 << i;
            end else if ((expected & req) == 0) next_grant = 0;
            clk = 1;
            #2;
            expected = next_grant;
            initialized = 1;
            checks = checks + 1;
            if (g !== expected)
                $fatal(1, "Check %0d resetn=%b r=%b g=%b expected=%b", checks, rn, req, g, expected);
            clk = 0;
            #1;
        end
    endtask

    initial begin
        step(0, 0);
        // Every reachable state, every request, and both reset levels.
        for (owner = 0; owner < 4; owner = owner + 1)
            for (mask = 0; mask < 8; mask = mask + 1)
                for (rst = 0; rst < 2; rst = rst + 1) begin
                    step(0, 0);
                    if (owner != 0) step(1, 3'b001 << (owner-1));
                    step(rst != 0, mask[2:0]);
                    step(1, 3'b111);
                    step(1, 0);
                    step(1, 3'b100);
                end
        // Deterministic varied histories, including reset during activity.
        for (k = 0; k < 512; k = k + 1)
            step((k % 31) != 0, ((k * 13) ^ (k >> 3)) & 7);
        $display("PASS: %0d clock steps checked", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Testbench timeout");
    end
endmodule
