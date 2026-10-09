`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic resetn = 1;
    logic [2:0] r = 0;
    wire [2:0] g;
    logic [2:0] expected = 0;
    integer checks = 0;
    integer owner, requests;
    TopModule dut (.clk(clk), .resetn(resetn), .r(r), .g(g));
    always #5 clk = ~clk;

    task automatic compare;
        begin
            if (g !== expected)
                $fatal(1, "t=%0t r=%b resetn=%b expected=%b actual=%b", $time, r, resetn, expected, g);
            checks = checks + 1;
        end
    endtask

    // Model the public grant behavior, without using DUT state codes.
    task automatic step(input logic rn, input logic [2:0] req);
        begin
            @(negedge clk);
            resetn = rn;
            r = req;
            #1;
            compare(); // Input or reset changes must not change a Moore grant.
            @(posedge clk);
            if (!rn) expected = 3'b000;
            else if (expected != 0) begin
                if ((expected & req) == 0) expected = 3'b000;
            end else begin
                case (req)
                    3'b000: expected = 3'b000;
                    3'b010, 3'b110: expected = 3'b010;
                    3'b100: expected = 3'b100;
                    default: expected = 3'b001;
                endcase
            end
            #1;
            compare();
        end
    endtask

    initial begin
        // No specified power-up value: first establish state by a reset edge.
        resetn = 0;
        @(posedge clk);
        #1;
        compare();
        for (owner = 0; owner < 4; owner = owner + 1) begin
            for (requests = 0; requests < 8; requests = requests + 1) begin
                step(0, 3'b111);
                if (owner != 0) step(1, 3'b001 << (owner - 1));
                step(1, requests[2:0]);
                step(1, requests[2:0]); // Hold or arbitrate after release bubble.
            end
        end
        // Active-owner resets, including assertion between edges.
        for (owner = 0; owner < 3; owner = owner + 1) begin
            step(0, 0);
            step(1, 3'b001 << owner);
            step(1, 3'b111);
            step(0, 3'b111);
            step(1, 3'b111);
        end
        step(0, 0);
        step(1, 0);
        $display("PASS: arbiter directed/exhaustive transitions, synchronous reset, stability; checks=%0d", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "timeout");
    end
endmodule
