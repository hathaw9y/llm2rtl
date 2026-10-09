`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic d = 1'b0;
    wire q;
    logic expected;
    logic [15:0] prng = 16'h35ac;
    integer checks = 0;
    TopModule dut (.clk(clk), .d(d), .q(q));

    task automatic check_output;
        begin
            if (q !== expected)
                $fatal(1, "Mismatch clk=%b d=%b q=%b expected=%b", clk, d, q, expected);
            checks = checks + 1;
        end
    endtask

    task automatic sample_edge(input logic sample, input integer wait_ns);
        begin
            d = sample;
            #(wait_ns);
            expected = d;
            clk = ~clk;
            #1;
            check_output();
            d = ~sample;
            #1;
            check_output();
            d = sample;
            #1;
            check_output();
        end
    endtask

    initial begin
        // First capture is a rising edge; no assumption about power-up q.
        sample_edge(1'b0, 3);
        sample_edge(1'b0, 5);
        sample_edge(1'b1, 2);
        sample_edge(1'b1, 4);
        sample_edge(1'b0, 6);
        sample_edge(1'b1, 2);
        sample_edge(1'b1, 3);
        sample_edge(1'b0, 4);
        for (integer i = 0; i < 256; i = i + 1) begin
            prng = {prng[14:0], prng[15] ^ prng[13] ^ prng[12] ^ prng[10]};
            sample_edge(prng[0], 2 + (i % 7));
        end
        $display("PASS: %0d capture/hold comparisons", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Development watchdog timeout");
    end
endmodule
