`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg [7:0] in = 0;
    wire [7:0] pedge;
    reg [7:0] prior_sample;
    reg [7:0] expected;
    reg history_valid = 0;
    integer checks = 0;
    integer a, b, bit_index;

    TopModule dut(.clk(clk), .in(in), .pedge(pedge));

    task sample(input [7:0] value);
        reg [7:0] held;
        begin
            clk = 0;
            held = pedge;
            in = value;
            #2;
            if (history_valid && pedge !== held)
                $fatal(1, "Output changed between clock edges");
            expected = 8'h00;
            for (integer j = 0; j < 8; j = j + 1)
                if (prior_sample[j] == 1'b0 && value[j] == 1'b1)
                    expected[j] = 1'b1;
            clk = 1;
            #1;
            if (history_valid) begin
                if (pedge !== expected)
                    $fatal(1, "sample %0d: prior=%h current=%h expected=%h actual=%h",
                           checks, prior_sample, value, expected, pedge);
                checks = checks + 1;
            end
            prior_sample = value;
            history_valid = 1;
            #1;
            clk = 0;
            #1;
            if (pedge !== expected && checks > 0)
                $fatal(1, "Output changed at falling clock edge");
        end
    endtask

    initial begin
        sample(8'h00);
        sample(8'h00);
        sample(8'hff);
        sample(8'hff);
        sample(8'h00);
        sample(8'haa);
        sample(8'h55);
        sample(8'haa);
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            sample(8'h00);
            sample(8'h01 << bit_index);
            sample(8'h01 << bit_index);
            sample(8'h00);
        end
        // A pulse wholly between clock samples must produce no detected edge.
        sample(8'h00);
        in = 8'hff;
        #1;
        if (pedge !== 8'h00) $fatal(1, "Asynchronous pulse changed output");
        in = 8'h00;
        #1;
        sample(8'h00);

        // Exhaust every ordered pair of vector samples.
        for (a = 0; a < 256; a = a + 1)
            for (b = 0; b < 256; b = b + 1) begin
                sample(a);
                sample(b);
            end
        $display("PASS: %0d sampled transitions and output stability checks", checks);
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "Timeout");
    end
endmodule
