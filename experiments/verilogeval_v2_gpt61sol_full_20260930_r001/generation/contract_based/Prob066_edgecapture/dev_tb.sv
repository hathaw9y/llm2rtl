module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic [31:0] in = 0;
    wire [31:0] out;
    logic prev_bit [0:31];
    logic sticky_bit [0:31];
    logic [31:0] expected;
    integer samples = 0;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .out(out));
    always #5 clk = ~clk;

    task automatic sample(input logic rst, input logic [31:0] value);
        @(negedge clk);
        reset = rst;
        in = value;
        @(posedge clk);
        for (integer b = 0; b < 32; b = b + 1) begin
            if (rst) sticky_bit[b] = 0;
            else if (prev_bit[b] == 1 && value[b] == 0) sticky_bit[b] = 1;
            prev_bit[b] = value[b];
            expected[b] = sticky_bit[b];
        end
        #1;
        if (out !== expected)
            $fatal(1, "FAIL sample=%0d reset=%b in=%h expected=%h actual=%h", samples, rst, value, expected, out);
        samples = samples + 1;
    endtask

    initial begin
        sample(1, 32'b0);
        sample(0, 32'b0);
        sample(0, 32'hffffffff);
        sample(0, 32'hffffffff);
        sample(0, 32'b0);
        sample(0, 32'hffffffff);
        sample(0, 32'b0);
        sample(1, 32'hffffffff);
        sample(0, 32'b0);
        sample(1, 32'b0);
        for (integer b = 0; b < 32; b = b + 1) begin
            sample(1, 32'b0);
            sample(0, 32'b1 << b);
            sample(0, 32'b0);
            sample(0, 32'b1 << b);
            sample(0, 32'b0);
        end
        // Reset and input changes away from clock edge must not alter output.
        @(negedge clk);
        reset = 1;
        in = 32'hffffffff;
        #2;
        if (out !== expected) $fatal(1, "FAIL asynchronous reset effect");
        reset = 0;
        in = 32'b0;
        // The next rising edge is unchanged from the previous sampled zero.
        @(posedge clk);
        #1;
        if (out !== expected) $fatal(1, "FAIL unsampled input pulse captured");
        for (integer n = 0; n < 1000; n = n + 1)
            sample((n % 23) == 0, $random);
        $display("PASS: %0d checked samples plus between-edge checks", samples);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "FAIL watchdog timeout");
    end
endmodule
