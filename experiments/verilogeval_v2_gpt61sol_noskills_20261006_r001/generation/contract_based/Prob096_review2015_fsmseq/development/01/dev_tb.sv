`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg data = 0;
    wire start_shifting;
    reg [3:0] window = 0;
    reg expected = 0;
    integer valid_bits = 0;
    integer checks = 0;
    integer stream, bit_index, k;
    TopModule dut(.clk(clk), .reset(reset), .data(data),
                  .start_shifting(start_shifting));

    task check_output;
        begin
            if (start_shifting !== expected)
                $fatal(1, "Mismatch check=%0d reset=%b data=%b history=%b expected=%b actual=%b",
                       checks, reset, data, window, expected, start_shifting);
            checks = checks + 1;
        end
    endtask

    // One sampled input, with checks both before and after the sampling edge.
    task step(input reg rst, input reg value);
        begin
            clk = 0;
            reset = rst;
            data = value;
            #2;
            check_output();
            clk = 1;
            if (rst) begin
                window = 0;
                valid_bits = 0;
                expected = 0;
            end else begin
                window = {window[2:0], value};
                if (valid_bits < 4) valid_bits = valid_bits + 1;
                if (valid_bits >= 4 && window == 4'b1101) expected = 1;
            end
            #1;
            check_output();
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        // Original specification gives no power-up guarantee. First reset
        // establishes the oracle before any output comparisons.
        reset = 1;
        #2; clk = 1;
        #1; check_output();
        clk = 0;
        #1;

        // Detection at exactly the fourth sampled bit.
        step(0, 1); step(0, 1); step(0, 0); step(0, 1);
        // Sticky for arbitrary later data.
        for (k = 0; k < 20; k = k + 1) step(0, k % 2);

        // Reset assertion between edges must not clear the found output.
        reset = 1;
        #2; check_output();
        reset = 0;
        #2; check_output();
        step(1, 1);
        // Reset must discard a three-bit prefix, even when data=1 would complete it.
        step(0, 1); step(0, 1); step(0, 0);
        step(1, 1);
        step(0, 1); step(0, 0); step(0, 1); step(0, 0);

        // Repeated ones retain the 11 suffix; failed 1100 clears the prefix.
        step(1, 0);
        step(0, 1); step(0, 1); step(0, 0); step(0, 0);
        step(0, 1); step(0, 1); step(0, 1); step(0, 1);
        step(0, 0); step(0, 1);

        // Exhaustive chronological streams, freshly reset before every stream.
        for (stream = 0; stream < 1024; stream = stream + 1) begin
            step(1, stream % 2);
            for (bit_index = 9; bit_index >= 0; bit_index = bit_index - 1)
                step(0, (stream >> bit_index) & 1);
            // Continue after each stream to check persistence and suffix matches.
            step(0, 1); step(0, 1); step(0, 0); step(0, 1);
            step(0, 0);
        end
        step(1, 0);
        step(1, 1);
        step(0, 0);
        $display("PASS: sequence, overlap, timing, sticky and synchronous reset checks (%0d comparisons)", checks);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Bounded development timeout");
    end
endmodule
