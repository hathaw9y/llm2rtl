`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic [7:0] in = 0;
    wire [23:0] out_bytes;
    wire done;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .out_bytes(out_bytes), .done(done));
    always #5 clk = ~clk;

    integer count = 0;
    integer checks = 0;
    integer messages = 0;
    logic pending = 0;
    logic [23:0] assembling = 0;
    logic [23:0] completed = 0;
    logic expected_done;
    logic [23:0] expected_bytes;
    logic [31:0] rng = 32'h71b36209;
    integer i, phase;

    task automatic step(input logic rst, input logic [7:0] byte_value);
        begin
            @(negedge clk);
            reset = rst;
            in = byte_value;
            @(posedge clk);
            expected_done = pending;
            expected_bytes = completed;
            pending = 0;
            if (rst) begin
                count = 0;
                expected_done = 0;
            end else begin
                if (count == 0) begin
                    if (byte_value[3]) begin
                        assembling = {16'b0, byte_value};
                        count = 1;
                    end
                end else begin
                    assembling = {assembling[15:0], byte_value};
                    count = count + 1;
                    if (count == 3) begin
                        completed = assembling;
                        pending = 1;
                        count = 0;
                    end
                end
            end
            #1;
            checks = checks + 1;
            if (done !== expected_done)
                $fatal(1, "done mismatch check=%0d got=%b expected=%b", checks, done, expected_done);
            if (expected_done) begin
                messages = messages + 1;
                if (out_bytes !== expected_bytes)
                    $fatal(1, "payload mismatch check=%0d got=%h expected=%h", checks, out_bytes, expected_bytes);
            end
        end
    endtask

    initial begin
        step(1, 0);
        // Original problem waveform, with explicit independent payload anchors.
        step(0, 8'h2c); step(0, 8'h81); step(0, 8'h09); step(0, 8'h6b);
        if (done !== 1'b1 || out_bytes !== 24'h2c8109) $fatal(1, "waveform anchor 1");
        step(0, 8'h0d); step(0, 8'h8d); step(0, 8'h6d);
        if (done !== 1'b1 || out_bytes !== 24'h6b0d8d) $fatal(1, "waveform anchor 2");
        step(0, 8'h12); step(0, 8'h01); step(0, 8'h0d);
        step(0, 8'h76); step(0, 8'h3d); step(0, 8'hed);
        step(0, 8'h8c); step(0, 8'hf9); step(0, 8'hce);
        step(0, 8'hc5); step(0, 8'haa);
        step(1, 0);
        // All search byte values, with arbitrary second/third bytes.
        for (i = 0; i < 256; i = i + 1) begin
            step(1, 0);
            step(0, i[7:0]);
            if (i[3]) begin
                step(0, 8'h00);
                step(0, 8'hff);
                step(0, 8'h00);
            end else begin
                step(0, 8'h00);
            end
        end
        // Cancel at each stage, including pending completion.
        for (phase = 0; phase < 4; phase = phase + 1) begin
            step(1, 0);
            for (i = 0; i < phase; i = i + 1) step(0, 8'hff);
            step(1, 8'hff);
            step(0, 0); step(0, 0); step(0, 0); step(0, 0);
        end
        // Dense back-to-back packets.
        for (i = 0; i < 100; i = i + 1) step(0, 8'hff);
        // Reproducible arbitrary bytes with intermittent resets.
        for (i = 0; i < 5000; i = i + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            step(rng[15:8] == 8'h00, rng[7:0]);
        end
        step(1, 0);
        $display("PASS checks=%0d messages=%0d", checks, messages);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "testbench timeout");
    end
endmodule
