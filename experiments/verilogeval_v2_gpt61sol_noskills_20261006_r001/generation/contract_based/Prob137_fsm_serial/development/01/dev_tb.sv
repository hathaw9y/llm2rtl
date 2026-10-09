`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg in = 1;
    wire done;
    TopModule dut(.clk(clk), .reset(reset), .in(in), .done(done));
    always #5 clk = ~clk;

    // Parser uses a remaining-sample count, independent of DUT state encoding.
    integer remaining = 0;
    reg recovering = 0;
    reg expected = 0;
    reg initialized = 0;
    integer samples = 0;
    integer completions = 0;
    integer b, j, n;
    reg [31:0] rng = 32'h4fa89231;

    always @(posedge clk) begin
        if (reset) begin
            remaining = 0;
            recovering = 0;
            expected = 0;
            initialized = 1;
        end else if (initialized) begin
            expected = 0;
            if (recovering) begin
                if (in) recovering = 0;
            end else if (remaining > 1) begin
                remaining = remaining - 1;
            end else if (remaining == 1) begin
                remaining = 0;
                if (in) begin
                    expected = 1;
                    completions = completions + 1;
                end else recovering = 1;
            end else if (!in) begin
                remaining = 9; // eight data samples followed by a stop sample
            end
        end
        #1;
        if (initialized && done !== expected)
            $fatal(1, "Sample %0d: done=%b expected=%b in=%b reset=%b remaining=%0d recovery=%b", samples, done, expected, in, reset, remaining, recovering);
        samples = samples + 1;
    end

    task step(input reg serial_bit, input reg rst);
        begin
            @(negedge clk);
            in = serial_bit;
            reset = rst;
            #1;
            // Input/reset changes alone must not alter synchronous outputs.
            if (initialized && done !== expected)
                $fatal(1, "Output changed without positive clock edge");
            @(posedge clk);
            #2;
        end
    endtask

    task frame(input reg [7:0] value, input reg valid_stop);
        integer k;
        begin
            step(0, 0);
            for (k = 0; k < 8; k = k + 1) step(value[k], 0);
            step(valid_stop, 0);
        end
    endtask

    initial begin
        step(1, 1);
        repeat (5) step(1, 0);
        // All possible bytes, with no extra idle cycles between frames.
        for (b = 0; b < 256; b = b + 1) frame(b[7:0], 1);
        if (completions != 256) $fatal(1, "Expected exactly 256 completed frames");
        // Reset while done is high, and reset held with line low.
        step(0, 1);
        repeat (3) step(0, 1);
        step(1, 0);
        frame(8'hff, 0);
        repeat (24) step(0, 0);
        step(1, 0); // recovery high must not assert done
        frame(8'h00, 1);
        frame(8'h55, 0);
        step(0, 1); // reset during recovery
        step(1, 0);
        frame(8'haa, 1);
        // Reset at every position in a frame.
        for (n = 0; n < 10; n = n + 1) begin
            step(1, 1);
            step(0, 0);
            for (j = 0; j < n; j = j + 1) step(j % 2, 0);
            step(0, 1);
            step(1, 0);
            frame(8'h81, 1);
        end
        for (n = 0; n < 2000; n = n + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            step(rng[0], (rng[8:1] == 8'h00));
        end
        step(1, 1);
        step(1, 0);
        frame(8'hfe, 1);
        step(1, 0);
        $display("PASS: serial framing, recovery, reset, exhaustive bytes and random streams (%0d samples)", samples);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Bounded timeout");
    end
endmodule
