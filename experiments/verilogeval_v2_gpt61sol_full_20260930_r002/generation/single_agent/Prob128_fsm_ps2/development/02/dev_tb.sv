`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg [7:0] in = 0;
    wire done;
    integer remaining = 0;
    integer checks = 0;
    integer i, pattern, k;
    reg expected_done = 0;
    reg old_done;
    reg [15:0] random_r = 16'hcafe;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .done(done));
    always #5 clk = ~clk;

    // Independent packet parser: two further bytes follow an accepted header.
    task step(input reg rst, input reg [7:0] byte_value);
        begin
            @(negedge clk);
            old_done = done;
            reset = rst;
            in = byte_value;
            #1;
            if (checks > 0 && done !== old_done)
                $fatal(1, "Output changed between clock edges");
            @(posedge clk);
            expected_done = 0;
            if (rst) remaining = 0;
            else if (remaining == 0) begin
                if (byte_value[3]) remaining = 2;
            end else begin
                remaining = remaining - 1;
                if (remaining == 0) expected_done = 1;
            end
            #1;
            checks = checks + 1;
            if (done !== expected_done)
                $fatal(1, "check %0d rst=%b byte=%h expected=%b actual=%b",
                       checks, rst, byte_value, expected_done, done);
        end
    endtask

    initial begin
        step(1, 8'hff);
        repeat (5) step(0, 8'h00);
        step(0, 8'h08);
        step(0, 8'h00);
        step(0, 8'hff);
        step(0, 8'h08);
        step(0, 8'hff);
        step(0, 8'h00);
        step(0, 8'h00);
        repeat (12) step(0, 8'hff);
        // Exhaust all header-bit streams of length eight.
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            step(1, 8'h08);
            for (k = 0; k < 8; k = k + 1)
                step(0, ((pattern >> k) & 1) ? 8'hff : 8'hf7);
        end
        // Reset interrupts search, each partial packet, and completion.
        for (k = 0; k < 4; k = k + 1) begin
            step(1, 8'h00);
            for (i = 0; i < k; i = i + 1) step(0, 8'h08);
            step(1, 8'hff);
            step(0, 8'h00);
            step(0, 8'h08);
            step(0, 8'h00);
            step(0, 8'h00);
        end
        for (i = 0; i < 1000; i = i + 1) begin
            random_r = {random_r[14:0], random_r[15] ^ random_r[13] ^ random_r[12] ^ random_r[10]};
            step(random_r[15:11] == 5'b00000, random_r[7:0]);
        end
        $display("PASS %0d packet and synchronous-reset checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
