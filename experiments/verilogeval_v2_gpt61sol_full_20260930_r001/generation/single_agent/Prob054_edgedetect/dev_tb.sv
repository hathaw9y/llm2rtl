`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic [7:0] in = 8'h00;
    wire [7:0] pedge;
    logic [7:0] previous_sample;
    logic [7:0] expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .in(in), .pedge(pedge));
    always #5 clk = ~clk;

    task automatic check_sample(input logic [7:0] value);
        @(negedge clk);
        in = value;
        expected = 8'h00;
        for (integer bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1)
            if (previous_sample[bit_idx] == 1'b0 && value[bit_idx] == 1'b1)
                expected[bit_idx] = 1'b1;
        @(posedge clk);
        #1;
        if (pedge !== expected)
            $fatal(1, "FAIL input=%h previous=%h expected=%h actual=%h", value, previous_sample, expected, pedge);
        previous_sample = value;
        checks = checks + 1;
        #1;
        in = ~value;
        #1;
        if (pedge !== expected)
            $fatal(1, "FAIL output changed between clock edges");
    endtask

    initial begin
        // No reset is specified; seed the sampled history with a clock.
        @(posedge clk);
        #1;
        previous_sample = 8'h00;
        check_sample(8'h00);
        check_sample(8'hff);
        check_sample(8'hff);
        check_sample(8'h00);
        check_sample(8'haa);
        check_sample(8'h55);
        check_sample(8'h55);
        for (integer idx = 0; idx < 256; idx = idx + 1)
            check_sample(8'(idx));
        for (integer idx = 0; idx < 256; idx = idx + 1)
            check_sample(8'($urandom));
        $display("PASS: %0d sampled transitions and registered-output checks", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "FAIL simulation timeout");
    end
endmodule
