`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic [7:0] d = 0;
    wire [7:0] q;
    logic [7:0] expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .d(d), .q(q));

    task automatic check_output(input logic [7:0] value);
        begin
            if (q !== value)
                $fatal(1, "q=%h expected=%h at time %0t", q, value, $time);
            checks = checks + 1;
        end
    endtask

    task automatic cycle(input logic rst, input logic [7:0] data);
        begin
            // Inputs change while clock is low; synchronous reset must wait.
            reset = rst;
            d = data;
            #2;
            check_output(expected);
            clk = 1;
            expected = rst ? 8'h00 : data;
            #1;
            check_output(expected);
            // Data and reset changes while high must not update the register.
            d = ~data;
            reset = ~rst;
            #2;
            check_output(expected);
            clk = 0;
            #1;
            check_output(expected);
        end
    endtask

    initial begin
        // Establish a defined value using a synchronous reset edge.
        reset = 1;
        d = 8'hff;
        #2;
        clk = 1;
        #1;
        expected = 8'h00;
        check_output(expected);
        clk = 0;
        #1;
        cycle(0, 8'hff);
        cycle(1, 8'hff);
        cycle(1, 8'haa);
        cycle(0, 8'h00);
        for (integer i = 0; i < 256; i = i + 1) begin
            cycle(0, i[7:0]);
            if ((i % 17) == 0)
                cycle(1, ~i[7:0]);
        end
        cycle(0, 8'h55);
        cycle(0, 8'haa);
        $display("PASS: synchronous reset and all 256 input values; %0d checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "timeout");
    end
endmodule
