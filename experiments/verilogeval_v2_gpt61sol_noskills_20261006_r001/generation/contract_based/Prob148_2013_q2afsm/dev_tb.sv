`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg resetn = 1;
    reg [2:0] r = 0;
    wire [2:0] g;
    integer owner = -1;
    integer cycles = 0;
    integer s, req, rst, i;
    reg [31:0] random_bits = 32'h13579bdf;
    TopModule dut (.clk(clk), .resetn(resetn), .r(r), .g(g));
    always #5 clk = ~clk;

    function automatic [2:0] expected_grant(input integer device);
        if (device < 0) expected_grant = 3'b000;
        else expected_grant = 3'b001 << device;
    endfunction

    task automatic check_grant;
        begin
            if (g !== expected_grant(owner))
                $fatal(1, "cycle=%0d owner=%0d r=%b resetn=%b expected=%b got=%b",
                       cycles, owner, r, resetn, expected_grant(owner), g);
        end
    endtask

    task automatic step(input [2:0] requests, input reg reset_value);
        begin
            @(negedge clk);
            r = requests;
            resetn = reset_value;
            #1;
            check_grant(); // Inputs and reset cannot change the state between edges.
            @(posedge clk);
            if (!reset_value) owner = -1;
            else if (owner >= 0) begin
                if (!requests[owner]) owner = -1;
            end else begin
                owner = -1;
                for (integer device = 2; device >= 0; device = device - 1)
                    if (requests[device]) owner = device;
            end
            cycles = cycles + 1;
            #1;
            check_grant();
        end
    endtask

    initial begin
        // No power-up state requirement: establish A by an actual reset edge.
        resetn = 0;
        r = 3'b111;
        @(posedge clk);
        #1;
        check_grant();
        step(3'b111, 1); // All request: device 0 wins.
        step(3'b111, 1);
        step(3'b110, 1); // Release has an idle cycle.
        step(3'b110, 1); // Device 1 wins next arbitration.
        step(3'b111, 1); // Higher priority arrival cannot preempt owner 1.
        step(3'b101, 1);
        step(3'b100, 1);
        step(3'b111, 1); // Neither higher priority requester can preempt owner 2.
        step(3'b111, 0); // Synchronous reset while grant is active.
        step(3'b000, 1);
        // Exhaustive state/request/reset combinations, setting up each state independently.
        for (s = -1; s < 3; s = s + 1)
            for (req = 0; req < 8; req = req + 1)
                for (rst = 0; rst < 2; rst = rst + 1) begin
                    step(3'b000, 0);
                    if (s >= 0) step(3'b001 << s, 1);
                    step(req[2:0], rst != 0);
                end
        for (i = 0; i < 500; i = i + 1) begin
            random_bits = {random_bits[30:0], random_bits[31] ^ random_bits[21] ^ random_bits[1] ^ random_bits[0]};
            step(random_bits[2:0], random_bits[7:4] != 4'b0000);
        end
        $display("PASS checked %0d cycles including exhaustive transitions and synchronous reset", cycles);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
