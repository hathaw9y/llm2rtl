`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic resetn = 0;
    logic [2:0] r = 0;
    wire [2:0] g;
    logic [2:0] expected = 0;
    integer checks = 0;
    integer owner, req, rst;
    TopModule dut (.clk(clk), .resetn(resetn), .r(r), .g(g));
    always #5 clk = ~clk;

    task automatic step(input logic rn, input logic [2:0] requests);
        logic [2:0] prior;
        begin
            @(negedge clk);
            prior = expected;
            resetn = rn;
            r = requests;
            #1;
            if (g !== prior) $fatal(1, "Output changed between clock edges");
            if (!rn) expected = 3'b000;
            else if (expected == 0) begin
                if (requests[0]) expected = 3'b001;
                else if (requests[1]) expected = 3'b010;
                else if (requests[2]) expected = 3'b100;
            end else if ((expected & requests) == 0) expected = 0;
            @(posedge clk);
            #1;
            checks = checks + 1;
            if (g !== expected)
                $fatal(1, "check=%0d resetn=%b r=%b expected=%b g=%b", checks, rn, requests, expected, g);
        end
    endtask

    initial begin
        @(posedge clk);
        #1;
        if (g !== 0) $fatal(1, "Initial synchronous reset failed");
        for (rst = 0; rst < 2; rst = rst + 1)
            for (owner = 0; owner < 4; owner = owner + 1)
                for (req = 0; req < 8; req = req + 1) begin
                    step(0, 0);
                    if (owner != 0) step(1, 3'b001 << (owner - 1));
                    step(rst != 0, req[2:0]);
                    step(1, req[2:0]);
                end
        for (req = 0; req < 256; req = req + 1)
            step((req % 19) != 0, ((req * 5) ^ (req >> 3)) & 7);
        $display("PASS: %0d checked cycles; all state/request/reset combinations", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Testbench timeout");
    end
endmodule
