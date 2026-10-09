`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic [7:0] d = 8'h00;
    wire [7:0] q;
    logic [7:0] expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .d(d), .q(q));

    task automatic check_output;
        begin
            if (q !== expected)
                $fatal(1, "Mismatch at %0t: q=%b expected=%b", $time, q, expected);
            checks = checks + 1;
        end
    endtask

    task automatic exercise(input logic [7:0] value);
        begin
            // Set data while clock is low; the old sample must hold.
            d = value;
            #2;
            check_output();
            // The original DFF rule defines the new expected value here.
            expected = value;
            clk = 1'b1;
            #1;
            check_output();
            // Data changes while high must not propagate.
            d = ~value;
            #2;
            check_output();
            clk = 1'b0;
            #1;
            check_output();
            // Further data changes while low must also hold.
            d = value ^ 8'hA5;
            #1;
            check_output();
        end
    endtask

    initial begin
        // No pre-first-capture output value is mandated by the problem.
        #2;
        d = 8'hA5;
        #2;
        expected = 8'hA5;
        clk = 1'b1;
        #1;
        check_output();
        clk = 1'b0;
        #1;
        check_output();
        for (integer i = 0; i < 256; i = i + 1)
            exercise(i[7:0]);
        for (integer i = 0; i < 8; i = i + 1) begin
            exercise(8'h01 << i);
            exercise(~(8'h01 << i));
        end
        exercise(8'hFF);
        exercise(8'hFF);
        exercise(8'b10xz01zx);
        exercise(8'h00);
        $display("PASS: positive-edge capture and inter-edge hold, %0d checks", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
