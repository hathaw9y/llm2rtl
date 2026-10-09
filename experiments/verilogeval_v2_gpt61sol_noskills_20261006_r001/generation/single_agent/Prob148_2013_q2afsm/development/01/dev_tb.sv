`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg resetn = 1;
    reg [2:0] r = 0;
    wire [2:0] g;
    reg [2:0] expected = 0;
    integer checks = 0;
    integer requests, owner, mask, n;
    TopModule dut (.clk(clk), .resetn(resetn), .r(r), .g(g));
    always #5 clk = ~clk;

    task step(input reg rn, input reg [2:0] req);
        reg [2:0] prior;
        begin
            @(negedge clk);
            prior = expected;
            resetn = rn;
            r = req;
            #1;
            if (g !== prior) $fatal(1, "Output changed before rising edge: got %b expected %b", g, prior);
            @(posedge clk);
            if (!rn) expected = 0;
            else if (expected != 0) begin
                if ((expected & req) == 0) expected = 0;
            end else begin
                if (req[0]) expected = 3'b001;
                else if (req[1]) expected = 3'b010;
                else if (req[2]) expected = 3'b100;
                else expected = 0;
            end
            #1;
            if (g !== expected) $fatal(1, "Mismatch resetn=%b r=%b got=%b expected=%b", rn, req, g, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Establish known state through a synchronous reset before checking outputs.
        resetn = 0;
        @(posedge clk);
        #1;
        if (g !== 3'b000) $fatal(1, "Reset failed");
        // Check all idle-state priority combinations.
        for (requests = 0; requests < 8; requests = requests + 1) begin
            step(0, 3'b111);
            step(1, requests[2:0]);
        end
        // For every owner, test all request combinations: holding, release,
        // the idle cycle on release, and subsequent arbitration.
        for (owner = 0; owner < 3; owner = owner + 1) begin
            for (mask = 0; mask < 8; mask = mask + 1) begin
                step(0, 0);
                step(1, 3'b001 << owner);
                step(1, mask[2:0]);
                step(1, mask[2:0]);
                step(0, 3'b111);
            end
        end
        // Longer mixed sequences, with resets while granted.
        for (n = 0; n < 300; n = n + 1) begin
            step((n % 37) != 0, ((n * 13) ^ (n >> 2)) & 7);
        end
        $display("PASS arbiter checks=%0d", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
