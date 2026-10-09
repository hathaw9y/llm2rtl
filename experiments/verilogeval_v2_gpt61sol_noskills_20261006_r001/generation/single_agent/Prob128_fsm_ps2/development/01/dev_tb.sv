`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg [7:0] in = 0;
    wire done;
    integer bytes_left = 0;
    integer cycles = 0;
    integer i, j;
    reg expected_done = 0;
    reg [31:0] rng = 32'h793123ab;
    TopModule dut(.clk(clk), .reset(reset), .in(in), .done(done));
    always #5 clk = ~clk;

    task step(input reg rst, input reg [7:0] data);
        begin
            @(negedge clk);
            reset = rst;
            in = data;
            // Neither a byte nor synchronous reset can change the output here.
            #1;
            if (cycles > 0 && done !== expected_done)
                $fatal(1, "Output changed between sampling edges, cycle %0d", cycles);
            @(posedge clk);
            if (rst) begin
                bytes_left = 0;
                expected_done = 0;
            end else if (bytes_left == 0) begin
                expected_done = 0;
                if (data[3]) bytes_left = 2;
            end else begin
                bytes_left = bytes_left - 1;
                expected_done = (bytes_left == 0);
            end
            #1;
            cycles = cycles + 1;
            if (done !== expected_done)
                $fatal(1, "Cycle %0d: reset=%b byte=%h expected done=%b got=%b", cycles, rst, data, expected_done, done);
        end
    endtask

    initial begin
        // No specified power-up state: begin observation after synchronous reset.
        step(1, 8'hff);
        repeat (8) step(0, 8'hf7);
        // All combinations of bit 3 in bytes two and three must be accepted.
        for (i = 0; i < 4; i = i + 1) begin
            step(0, 8'h08);
            step(0, (i & 1) ? 8'hff : 8'h00);
            step(0, (i & 2) ? 8'h08 : 8'hf7);
        end
        step(0, 8'h00);
        // Continuous marked bytes produce one completion per three bytes.
        repeat (15) step(0, 8'hff);
        // Reset while searching, partially receiving, and signalling completion.
        for (i = 0; i < 4; i = i + 1) begin
            step(1, 8'h08);
            for (j = 0; j < i; j = j + 1) step(0, 8'h08);
            step(1, 8'hff);
            step(0, 8'h00);
            step(0, 8'h08);
            step(0, 8'h00);
            step(0, 8'h00);
            step(0, 8'h00);
        end
        repeat (1000) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            step(rng[15:8] == 0, rng[7:0]);
        end
        $display("PASS: %0d cycles of byte framing and synchronous reset checks", cycles);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
