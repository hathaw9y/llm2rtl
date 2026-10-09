`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic [7:0] in = 0;
    wire done;
    integer remaining = 0;
    integer checks = 0;
    integer messages = 0;
    bit known = 0;
    bit expected_done = 0;
    logic [31:0] rng = 32'h184fc25a;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .done(done));
    always #5 clk = ~clk;

    // Count bytes still needed, independently of the DUT state encoding.
    always @(posedge clk) begin
        if (reset) begin
            remaining = 0;
            expected_done = 0;
            known = 1;
        end else if (known) begin
            expected_done = 0;
            if (remaining != 0) begin
                remaining = remaining - 1;
                if (remaining == 0) begin
                    expected_done = 1;
                    messages = messages + 1;
                end
            end else if (in[3]) remaining = 2;
        end
        #1;
        if (known) begin
            checks = checks + 1;
            if (done !== expected_done)
                $fatal(1, "edge check %0d in=%h reset=%b expected=%b got=%b", checks, in, reset, expected_done, done);
        end
    end

    task automatic step(input logic [7:0] byte_value, input bit rst);
        @(negedge clk);
        in = byte_value;
        reset = rst;
        @(posedge clk);
        #2;
        // Output must remain stable between sampling edges.
        #1;
        if (done !== expected_done) $fatal(1, "Output changed between edges");
    endtask

    initial begin : stimulus
        integer a, b, i, phase;
        step(8'hff, 1);
        for (i = 0; i < 16; i = i + 1) step(8'(i & 7), 0);
        for (a = 0; a < 2; a = a + 1)
            for (b = 0; b < 2; b = b + 1) begin
                step(8'h08, 0);
                step(a ? 8'hff : 8'h00, 0);
                step(b ? 8'h08 : 8'hf7, 0);
            end
        // All input byte values in search and in both payload positions.
        for (i = 0; i < 256; i = i + 1) begin
            step(0, 1);
            step(8'(i), 0);
            step(8'h08, 0);
            step(8'(i), 0);
            step(8'(255-i), 0);
            step(0, 1);
            step(8'h08, 0);
            step(8'(i), 0);
            step(8'(255-i), 0);
        end
        // Abort/reset at every partial-message phase, including done.
        for (phase = 0; phase <= 3; phase = phase + 1) begin
            step(0, 1);
            for (i = 0; i < phase; i = i + 1) step(8'h08, 0);
            step(8'hff, 1);
            step(8'h00, 0);
            step(8'h08, 0);
            step(8'h00, 0);
            step(8'h00, 0);
        end
        // Assert reset within the done cycle, proving synchronous behavior.
        step(0, 1);
        step(8'h08, 0);
        step(0, 0);
        step(0, 0);
        @(negedge clk);
        reset = 1;
        #1;
        if (done !== 1'b1) $fatal(1, "Reset acted asynchronously");
        @(posedge clk);
        #2;
        if (done !== 1'b0) $fatal(1, "Reset did not clear done");
        for (i = 0; i < 1000; i = i + 1) begin
            rng = {rng[30:0], rng[31] ^ rng[21] ^ rng[1] ^ rng[0]};
            step(rng[7:0], (i % 97 == 0));
        end
        if (checks < 3000 || messages < 100) $fatal(1, "Insufficient exercised cases");
        $display("PASS checks=%0d messages=%0d", checks, messages);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
