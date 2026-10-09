`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic reset = 1'b0;
    logic [7:0] d = 8'h00;
    wire [7:0] q;
    logic [7:0] expected;
    integer checks = 0;
    integer i;
    TopModule dut (.clk(clk), .reset(reset), .d(d), .q(q));

    task automatic check_q(input logic [7:0] value);
        begin
            if (q !== value)
                $fatal(1, "Mismatch at %0t: q=%h expected=%h", $time, q, value);
            checks = checks + 1;
        end
    endtask

    // Inputs change with the clock low, well away from the falling edge.
    task automatic cycle(input logic rst, input logic [7:0] data);
        begin
            reset = rst;
            d = data;
            #1;
            check_q(expected);
            clk = 1'b1;
            #1;
            check_q(expected);
            // Mutate data while high to verify sampling at the falling edge.
            d = ~data;
            #1;
            check_q(expected);
            d = data;
            #1;
            clk = 1'b0;
            if (rst) expected = 8'h34;
            else expected = data;
            #1;
            check_q(expected);
        end
    endtask

    initial begin
        // No assertion about unspecified power-up state.
        #2;
        clk = 1'b1;
        reset = 1'b1;
        d = 8'hff;
        #2;
        clk = 1'b0;
        expected = 8'h34;
        #1;
        check_q(expected);

        cycle(1'b0, 8'ha5);
        // A reset pulse with no falling edge must not alter the stored value.
        reset = 1'b1;
        d = 8'h00;
        #2;
        check_q(expected);
        reset = 1'b0;
        #2;
        check_q(expected);
        cycle(1'b1, 8'h00);
        cycle(1'b1, 8'hff);
        cycle(1'b0, 8'h00);
        cycle(1'b0, 8'hff);
        for (i = 0; i < 256; i = i + 1)
            cycle(1'b0, i[7:0]);
        cycle(1'b1, 8'hcb);
        cycle(1'b0, 8'h81);
        $display("PASS: %0d falling-edge/reset/hold checks", checks);
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Timeout");
    end
endmodule
