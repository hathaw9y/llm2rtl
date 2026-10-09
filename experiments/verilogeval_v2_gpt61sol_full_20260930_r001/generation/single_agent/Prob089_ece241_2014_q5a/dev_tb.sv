`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic x = 0;
    wire z;
    integer checks = 0;
    integer width, value, bit_idx;
    integer expected_word;
    logic saved_z;
    TopModule dut (.clk(clk), .areset(areset), .x(x), .z(z));
    always #5 clk = ~clk;

    task automatic reset_machine;
        @(negedge clk);
        #1 areset = 1;
        #1;
        if (z !== 1'b0) $fatal(1, "Asynchronous reset failed");
        checks = checks + 1;
        #1 areset = 0;
    endtask

    initial begin
        for (width = 1; width <= 10; width = width + 1) begin
            for (value = 0; value < (1 << width); value = value + 1) begin
                reset_machine();
                expected_word = (-value) & ((1 << width) - 1);
                for (bit_idx = 0; bit_idx < width; bit_idx = bit_idx + 1) begin
                    @(negedge clk);
                    saved_z = z;
                    x = (value >> bit_idx) & 1;
                    #1;
                    if (z !== saved_z) $fatal(1, "Output is not Moore");
                    @(posedge clk);
                    #1;
                    if (z !== ((expected_word >> bit_idx) & 1))
                        $fatal(1, "Mismatch width=%0d value=%0d bit=%0d z=%b", width, value, bit_idx, z);
                    checks = checks + 1;
                end
            end
        end
        reset_machine();
        // Long number: leading zeros, first one, then alternating bits.
        for (bit_idx = 0; bit_idx < 256; bit_idx = bit_idx + 1) begin
            @(negedge clk);
            if (bit_idx < 100) x = 0;
            else if (bit_idx == 100) x = 1;
            else x = bit_idx & 1;
            @(posedge clk);
            #1;
            if (z !== ((bit_idx < 100) ? 1'b0 : ((bit_idx == 100) ? 1'b1 : ~x)))
                $fatal(1, "Long stream mismatch");
            checks = checks + 1;
        end
        reset_machine();
        $display("PASS: %0d checks; exhaustive widths 1..10, Moore stability, long stream, asynchronous reset", checks);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Testbench timeout");
    end
endmodule
