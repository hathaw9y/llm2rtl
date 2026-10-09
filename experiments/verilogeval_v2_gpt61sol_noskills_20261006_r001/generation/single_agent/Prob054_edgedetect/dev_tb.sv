`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg [7:0] in = 0;
    wire [7:0] pedge;
    reg [7:0] last_sample;
    reg [7:0] expected;
    reg [7:0] held_output;
    integer checks = 0;
    integer bit_index;
    integer value;

    TopModule dut (.clk(clk), .in(in), .pedge(pedge));
    always #5 clk = ~clk;

    task sample(input [7:0] next_input);
        begin
            @(negedge clk);
            held_output = pedge;
            in = next_input;
            #1;
            if (pedge !== held_output)
                $fatal(1, "Output changed between rising clock edges");
            expected = 8'h00;
            for (integer b = 0; b < 8; b = b + 1)
                if ((last_sample[b] == 1'b0) && (next_input[b] == 1'b1))
                    expected[b] = 1'b1;
            @(posedge clk);
            #1;
            if (pedge !== expected)
                $fatal(1, "check %0d: previous=%h input=%h expected=%h got=%h",
                       checks, last_sample, next_input, expected, pedge);
            last_sample = next_input;
            checks = checks + 1;
        end
    endtask

    initial begin
        // No reset or initial state is specified. A zero sample establishes
        // known history and yields zero regardless of the unknown history.
        @(posedge clk);
        #1;
        if (pedge !== 8'h00) $fatal(1, "Zero input must give no rising edges");
        last_sample = 8'h00;
        sample(8'hff);
        sample(8'hff);
        sample(8'h00);
        sample(8'h00);
        sample(8'haa);
        sample(8'h55);
        sample(8'haa);
        sample(8'h00);
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            sample(8'h01 << bit_index);
            sample(8'h01 << bit_index);
            sample(8'h00);
        end
        for (value = 0; value < 256; value = value + 1) begin
            sample(value);
            sample(~value);
        end
        $display("PASS: %0d sampled transitions and output hold checks", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
