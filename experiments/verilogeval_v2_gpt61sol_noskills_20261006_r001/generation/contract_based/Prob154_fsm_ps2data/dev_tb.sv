`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 1;
    reg [7:0] in = 0;
    wire [23:0] out_bytes;
    wire done;
    TopModule dut(.clk(clk), .reset(reset), .in(in), .out_bytes(out_bytes), .done(done));
    integer count = 0;
    integer cycles = 0;
    integer reports = 0;
    reg pending = 0;
    reg expected_done = 0;
    reg [23:0] assembling;
    reg [23:0] completed;
    reg [23:0] expected_packet;
    reg [31:0] rng = 32'h456abcde;
    integer i, phase;

    task verify;
        begin
            if (done !== expected_done)
                $fatal(1, "done mismatch at %0t cycle %0d expected %b got %b", $time, cycles, expected_done, done);
            if (expected_done && out_bytes !== expected_packet)
                $fatal(1, "packet mismatch at %0t expected %h got %h", $time, expected_packet, out_bytes);
        end
    endtask

    // Each call advances exactly ten ns: inputs and rising edge at +5,
    // falling edge at +10. Checks follow NBA settling by one ps.
    task step(input reg rst, input reg [7:0] value);
        begin
            #4.999;
            reset = rst;
            in = value;
            if (rst) begin
                expected_done = 0;
                pending = 0;
                count = 0;
            end else begin
                expected_done = pending;
                if (pending) begin
                    expected_packet = completed;
                    reports = reports + 1;
                end
                pending = 0;
                if (count == 0) begin
                    if (value[3]) begin
                        assembling[23:16] = value;
                        count = 1;
                    end
                end else if (count == 1) begin
                    assembling[15:8] = value;
                    count = 2;
                end else begin
                    assembling[7:0] = value;
                    completed = assembling;
                    pending = 1;
                    count = 0;
                end
            end
            clk = 1;
            cycles = cycles + 1;
            #0.001; verify;
            #4.999; clk = 0;
            #0.001; verify;
        end
    endtask

    initial begin
        #0.001;
        if (done !== 1'bx) $fatal(1, "Expected initial unknown done before reset edge");
        // Original waveform: edges at 5, 15, ... 185ns, falling at 10 ... 190ns.
        step(1, 8'h00);
        step(0, 8'h2c); step(0, 8'h81); step(0, 8'h09);
        step(0, 8'h6b); step(0, 8'h0d); step(0, 8'h8d);
        step(0, 8'h6d); step(0, 8'h12); step(0, 8'h01);
        step(0, 8'h0d); step(0, 8'h76); step(0, 8'h3d);
        step(0, 8'hed); step(0, 8'h8c); step(0, 8'hf9);
        step(0, 8'hce); step(0, 8'hc5); step(0, 8'haa);
        if (reports != 5) $fatal(1, "Original waveform must report five packets");
        step(1, 8'hff);
        for (i=0; i<256; i=i+1)
            if ((i & 8) == 0) step(0, i[7:0]);
        // Every byte value in every packet position, with gap/start cases.
        for (i=0; i<256; i=i+1) begin
            step(0, i[7:0] | 8'h08);
            step(0, i[7:0]);
            step(0, 8'hff ^ i[7:0]);
            step(0, 8'h00);
        end
        // Reset interrupts each phase, including a queued report.
        for (phase=0; phase<4; phase=phase+1) begin
            step(1, 8'h00);
            for (i=0; i<phase; i=i+1) step(0, 8'h08+i);
            step(1, 8'hff);
            step(0, 8'h00); step(0, 8'h00);
        end
        // Reset pulses between clock edges must have no effect.
        step(0, 8'h28); step(0, 8'h11); step(0, 8'h42);
        #1; reset = 1;
        #1; verify;
        reset = 0;
        #2.999; clk = 1;
        expected_done = 1; expected_packet = completed;
        pending = 0; count = 0; in = 0;
        #0.001; verify;
        #4.999; clk = 0;
        #0.001; verify;
        for (i=0; i<1500; i=i+1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            step((i % 47) == 0, rng[7:0]);
        end
        step(1, 0);
        $display("PASS: original waveform, packet boundaries, synchronous resets, exhaustive payloads and random stream");
        $finish;
    end
    initial begin
        #100000; $fatal(1, "Timeout");
    end
endmodule
