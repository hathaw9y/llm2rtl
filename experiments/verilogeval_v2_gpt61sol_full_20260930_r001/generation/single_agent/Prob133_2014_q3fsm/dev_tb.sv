module dev_tb;
    logic clk = 0;
    logic reset = 0, s = 0, w = 0;
    wire z;
    TopModule dut (.clk(clk), .reset(reset), .s(s), .w(w), .z(z));
    always #5 clk = ~clk;
    bit active = 0;
    bit expected = 0;
    integer samples = 0, ones = 0, checks = 0;
    integer a, b, k;

    task automatic step(input bit rst, input bit start, input bit sample);
        @(negedge clk);
        reset = rst; s = start; w = sample;
        @(posedge clk);
        if (rst) begin
            active = 0; samples = 0; ones = 0; expected = 0;
        end else if (!active) begin
            expected = 0;
            if (start) active = 1;
        end else begin
            expected = 0;
            samples = samples + 1;
            ones = ones + int'(sample);
            if (samples == 3) begin
                expected = (ones == 2);
                samples = 0; ones = 0;
            end
        end
        #1;
        checks = checks + 1;
        if (z !== expected)
            $fatal(1, "FAIL check=%0d expected=%b actual=%b", checks, expected, z);
    endtask

    initial begin
        step(1, 0, 0);
        repeat (5) step(0, 0, 1);
        // All pairs of adjacent windows, including consecutive passing windows.
        for (a = 0; a < 8; a = a + 1) begin
            for (b = 0; b < 8; b = b + 1) begin
                step(1, 0, 0);
                step(0, 1, 1);
                for (k = 0; k < 3; k = k + 1) step(0, k[0], (a >> k) & 1);
                for (k = 0; k < 3; k = k + 1) step(0, k[0], (b >> k) & 1);
                step(0, 0, 0);
            end
        end
        // Reset at varying window positions and random idle/start activity.
        for (k = 0; k < 2000; k = k + 1)
            step(($urandom_range(0, 23) == 0), $urandom_range(0, 1), $urandom_range(0, 1));
        step(1, 1, 1);
        $display("PASS: %0d cycle checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "FAIL: timeout");
    end
endmodule
