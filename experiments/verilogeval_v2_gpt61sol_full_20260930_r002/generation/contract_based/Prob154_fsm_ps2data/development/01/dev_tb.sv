`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 1;
    logic [7:0] in = 0;
    wire [23:0] out_bytes;
    wire done;
    TopModule dut(.*);
    always #5 clk = ~clk;
    integer count = 0;
    integer checks = 0;
    logic expected_done = 0;
    logic [23:0] assembled = 0;
    logic [23:0] expected_packet = 0;
    logic [31:0] prng = 32'h197253ab;
    integer i;

    // Independent stream parser: collect three bytes, then publish packet.
    always @(posedge clk) begin
        if (reset) begin
            count = 0;
            expected_done = 0;
        end else begin
            expected_done = 0;
            if (count == 0) begin
                if (in[3] == 1'b1) begin
                    assembled = {in, 16'b0};
                    count = 1;
                end
            end else if (count == 1) begin
                assembled[15:8] = in;
                count = 2;
            end else begin
                assembled[7:0] = in;
                expected_packet = assembled;
                count = 0;
                expected_done = 1;
            end
        end
        #1;
        if (done !== expected_done)
            $fatal(1, "done mismatch at %0t expected %b actual %b", $time, expected_done, done);
        if (expected_done && out_bytes !== expected_packet)
            $fatal(1, "packet mismatch at %0t expected %h actual %h", $time, expected_packet, out_bytes);
        checks = checks + 1;
    end
    always @(negedge clk) begin
        if (done !== expected_done) $fatal(1, "done changed within cycle");
        if (expected_done && out_bytes !== expected_packet) $fatal(1, "payload changed within cycle");
    end

    task automatic wave_step(input logic rst_value, input logic [7:0] byte_value,
                             input logic done_value, input logic [23:0] packet_value);
        @(posedge clk);
        reset <= rst_value;
        in <= byte_value;
        #2;
        if (done !== done_value) $fatal(1, "waveform done mismatch at %0t", $time);
        if (done_value && out_bytes !== packet_value) $fatal(1, "waveform packet mismatch at %0t", $time);
        @(negedge clk);
        #1;
        if (done !== done_value) $fatal(1, "waveform falling-edge mismatch");
        if (done_value && out_bytes !== packet_value) $fatal(1, "waveform falling payload mismatch");
    endtask
    task automatic feed(input logic rst_value, input logic [7:0] byte_value);
        @(negedge clk);
        reset = rst_value;
        in = byte_value;
        @(posedge clk);
        #2;
    endtask
    initial begin
        // Exact original 5 ns through 190 ns edge relationships.
        wave_step(1, 8'h00, 0, 0);
        wave_step(0, 8'h2c, 0, 0);
        wave_step(0, 8'h81, 0, 0);
        wave_step(0, 8'h09, 0, 0);
        wave_step(0, 8'h6b, 1, 24'h2c8109);
        wave_step(0, 8'h0d, 0, 0);
        wave_step(0, 8'h8d, 0, 0);
        wave_step(0, 8'h6d, 1, 24'h6b0d8d);
        wave_step(0, 8'h12, 0, 0);
        wave_step(0, 8'h01, 0, 0);
        wave_step(0, 8'h0d, 1, 24'h6d1201);
        wave_step(0, 8'h76, 0, 0);
        wave_step(0, 8'h3d, 0, 0);
        wave_step(0, 8'hed, 1, 24'h0d763d);
        wave_step(0, 8'h8c, 0, 0);
        wave_step(0, 8'hf9, 0, 0);
        wave_step(0, 8'hce, 1, 24'hed8cf9);
        wave_step(0, 8'hc5, 0, 0);
        wave_step(0, 8'haa, 0, 0);
        // Each possible boundary candidate with clean reset, including all
        // bit-3-clear values, and bit-3-clear second and third bytes.
        for (i = 0; i < 256; i = i + 1) begin
            feed(1, 8'hff);
            feed(0, i[7:0]);
            feed(0, 8'h00);
            feed(0, 8'hff);
            feed(0, 8'h00);
        end
        // Reset aborts at each partial-packet position and during done.
        for (i = 0; i < 3; i = i + 1) begin
            feed(1, 0);
            feed(0, 8'h08);
            if (i >= 1) feed(0, 8'h55);
            if (i >= 2) feed(0, 8'haa);
            feed(1, 8'hff);
            feed(0, 0);
            feed(0, 8'h08);
            feed(0, 8'hff);
            feed(0, 8'h00);
        end
        // Continuous marked input must yield exactly one done every 3 cycles.
        for (i = 0; i < 30; i = i + 1) feed(0, 8'hff);
        for (i = 0; i < 1000; i = i + 1) begin
            prng = prng ^ (prng << 13);
            prng = prng ^ (prng >> 17);
            prng = prng ^ (prng << 5);
            feed((i % 73) == 0, prng[7:0]);
        end
        feed(1, 0);
        @(negedge clk);
        #2;
        $display("PASS independent stream and waveform checks: %0d edges", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
