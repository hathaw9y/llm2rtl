`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 1;
    reg [7:0] in = 0;
    wire [23:0] out_bytes;
    wire done;
    TopModule dut(.clk(clk), .reset(reset), .in(in), .out_bytes(out_bytes), .done(done));

    integer count = 0;
    integer checks = 0;
    integer i;
    reg due = 0;
    reg expected_done;
    reg [23:0] collected;
    reg [23:0] completed;
    reg [23:0] expected_packet;
    reg [7:0] sample;
    reg [31:0] rng = 32'h9136abcd;

    // Each call places inputs and the rising edge at the original timestamp.
    // Output checks occur after NBA settling and again on the falling edge.
    task tick(input reg rst, input reg [7:0] byte_value,
              input integer waveform_done, input reg [23:0] waveform_packet);
        begin
            reset = rst;
            in = byte_value;
            if (rst) begin
                count = 0;
                due = 0;
                expected_done = 0;
            end else begin
                expected_done = due;
                if (due) expected_packet = completed;
                due = 0;
                if (count == 0) begin
                    if (byte_value[3]) begin
                        collected = {byte_value, 16'b0};
                        count = 1;
                    end
                end else if (count == 1) begin
                    collected[15:8] = byte_value;
                    count = 2;
                end else begin
                    collected[7:0] = byte_value;
                    completed = collected;
                    due = 1;
                    count = 0;
                end
            end
            clk = 1;
            #1;
            if (done !== expected_done)
                $fatal(1, "done mismatch at %t: got %b expected %b", $time, done, expected_done);
            if (expected_done && out_bytes !== expected_packet)
                $fatal(1, "packet mismatch at %t: got %h expected %h", $time, out_bytes, expected_packet);
            if (waveform_done >= 0) begin
                if (done !== (waveform_done == 1)) $fatal(1, "Original waveform done mismatch");
                if (waveform_done == 1 && out_bytes !== waveform_packet)
                    $fatal(1, "Original waveform packet mismatch");
            end
            checks = checks + 1;
            #4; clk = 0;
            #1;
            if (done !== expected_done) $fatal(1, "done changed between rising edges");
            if (expected_done && out_bytes !== expected_packet) $fatal(1, "packet unstable");
            #4;
        end
    endtask

    initial begin
        #1;
        if (done !== 1'bx) $fatal(1, "done must be unknown before first clock/reset");
        #4;
        tick(1, 8'h00, 0, 0); // 5 ns
        tick(0, 8'h2c, 0, 0); // 15 ns
        tick(0, 8'h81, 0, 0);
        tick(0, 8'h09, 0, 0);
        tick(0, 8'h6b, 1, 24'h2c8109);
        tick(0, 8'h0d, 0, 0);
        tick(0, 8'h8d, 0, 0);
        tick(0, 8'h6d, 1, 24'h6b0d8d);
        tick(0, 8'h12, 0, 0);
        tick(0, 8'h01, 0, 0);
        tick(0, 8'h0d, 1, 24'h6d1201);
        tick(0, 8'h76, 0, 0);
        tick(0, 8'h3d, 0, 0);
        tick(0, 8'hed, 1, 24'h0d763d);
        tick(0, 8'h8c, 0, 0);
        tick(0, 8'hf9, 0, 0);
        tick(0, 8'hce, 1, 24'hed8cf9);
        tick(0, 8'hc5, 0, 0);
        tick(0, 8'haa, 0, 0);

        // Reset in every collection phase and with a completed packet pending.
        for (i = 0; i < 4; i = i + 1) begin
            tick(1, 8'hff, -1, 0);
            if (i >= 1) tick(0, 8'h08, -1, 0);
            if (i >= 2) tick(0, 8'h00, -1, 0);
            if (i >= 3) tick(0, 8'hff, -1, 0);
            tick(1, 8'h08, -1, 0);
            tick(0, 8'h00, -1, 0);
            tick(0, 8'hf7, -1, 0);
        end
        // All bit-3-clear byte values must be discarded while searching.
        for (i = 0; i < 256; i = i + 1)
            if ((i & 8) == 0) tick(0, i[7:0], -1, 0);
        // Packets permit either bit-3 value for their second/third bytes.
        for (i = 0; i < 256; i = i + 1) begin
            tick(0, 8'h08, -1, 0);
            tick(0, i[7:0], -1, 0);
            tick(0, ~i[7:0], -1, 0);
        end
        for (i = 0; i < 1000; i = i + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            sample = rng[7:0];
            tick((rng[15:8] == 0), sample, -1, 0);
        end
        tick(1, 0, -1, 0);
        tick(0, 8'h08, -1, 0);
        tick(0, 8'h00, -1, 0);
        tick(0, 8'hff, -1, 0);
        tick(0, 8'h00, -1, 0);
        tick(0, 8'h00, -1, 0);
        $display("PASS: %0d cycles checked, original waveform and boundary cases", checks);
        $finish;
    end
    initial begin
        #50000;
        $fatal(1, "Timeout");
    end
endmodule
