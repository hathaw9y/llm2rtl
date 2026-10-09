`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic [7:0] d = 8'h00;
    wire [7:0] q;
    logic [7:0] expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .d(d), .q(q));

    task automatic check_q(input logic [7:0] value);
        if (q !== value)
            $fatal(1, "Mismatch at %0t: expected %h, got %h", $time, value, q);
        checks = checks + 1;
    endtask

    task automatic cycle(input logic [7:0] value);
        d = value;
        #2;
        check_q(expected);
        clk = 1'b1;
        expected = value;
        #1;
        check_q(expected);
        d = ~value;
        #2;
        check_q(expected);
        clk = 1'b0;
        #1;
        check_q(expected);
    endtask

    initial begin
        // There is no reset or specified initialized value; establish state
        // on the first rising edge before checking the output.
        #2;
        clk = 1'b1;
        expected = 8'h00;
        #1;
        check_q(expected);
        clk = 1'b0;
        #1;
        cycle(8'hff);
        cycle(8'h00);
        cycle(8'haa);
        cycle(8'h55);
        for (integer bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            cycle(8'h01 << bit_index);
            cycle(~(8'h01 << bit_index));
        end
        for (integer value = 0; value < 256; value = value + 1)
            cycle(value[7:0]);
        // Four-state sampling also follows the D input directly.
        cycle(8'b10xz01zx);
        cycle(8'h69);
        $display("PASS: %0d checks of positive-edge capture and between-edge hold", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
