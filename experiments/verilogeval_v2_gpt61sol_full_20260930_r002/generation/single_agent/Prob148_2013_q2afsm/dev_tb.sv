`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic resetn = 1;
    logic [2:0] r = 0;
    wire [2:0] g;
    logic [2:0] expected;
    bit initialized = 0;
    integer checks = 0;
    integer owner, first_req, second_req;
    TopModule dut (.clk(clk), .resetn(resetn), .r(r), .g(g));

    // Oracle stores the granted device, independent of DUT state encoding.
    task automatic step(input logic rst_n, input logic [2:0] requests);
        logic [2:0] next_grant;
        begin
            resetn = rst_n;
            r = requests;
            #2;
            if (initialized && g !== expected)
                $fatal(1, "Output changed before rising edge: expected %b got %b", expected, g);
            if (!rst_n) next_grant = 3'b000;
            else if (expected != 3'b000) begin
                if ((expected & requests) != 3'b000) next_grant = expected;
                else next_grant = 3'b000;
            end else if (requests[0]) next_grant = 3'b001;
            else if (requests[1]) next_grant = 3'b010;
            else if (requests[2]) next_grant = 3'b100;
            else next_grant = 3'b000;
            #3 clk = 1;
            #1;
            expected = next_grant;
            initialized = 1;
            checks = checks + 1;
            if (g !== expected)
                $fatal(1, "Check %0d resetn=%b r=%b expected=%b got=%b", checks, rst_n, requests, expected, g);
            #4 clk = 0;
        end
    endtask

    initial begin
        step(0, 3'b111);
        // Every pair of request patterns starting in idle and each grant state.
        for (owner = 0; owner < 4; owner = owner + 1) begin
            for (first_req = 0; first_req < 8; first_req = first_req + 1) begin
                for (second_req = 0; second_req < 8; second_req = second_req + 1) begin
                    step(0, 3'b111);
                    if (owner != 0) step(1, 3'b001 << (owner - 1));
                    step(1, first_req[2:0]);
                    step(1, second_req[2:0]);
                    // Reset while active must wait for the next positive edge.
                    step(0, 3'b111);
                    step(1, 3'b000);
                end
            end
        end
        $display("PASS: %0d arbiter cycle checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
