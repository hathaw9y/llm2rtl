`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg [7:0] d = 8'h00;
    wire [7:0] q;
    reg [7:0] expected;
    reg [7:0] initial_value;
    integer checks = 0;
    integer i;
    TopModule dut (.clk(clk), .d(d), .q(q));

    task check_q(input [7:0] wanted);
        begin
            if (q !== wanted)
                $fatal(1, "q mismatch at %0t: got %b expected %b", $time, q, wanted);
            checks = checks + 1;
        end
    endtask

    task capture(input [7:0] value);
        begin
            // Drive while low and verify that data alone cannot change q.
            d = value;
            #2;
            check_q(expected);
            clk = 1;
            expected = value;
            #1; // Sample after nonblocking assignments settle.
            check_q(expected);
            // Data changes while high must not propagate to q.
            d = ~value;
            #2;
            check_q(expected);
            clk = 0;
            #1;
            check_q(expected);
            d = value ^ 8'h5a;
            #1;
            check_q(expected);
        end
    endtask

    initial begin
        // Observe initial storage without imposing an unspecified power-up value.
        #1;
        initial_value = q;
        d = 8'hff;
        #2;
        check_q(initial_value);
        d = 8'h00;
        #2;
        check_q(initial_value);
        clk = 1;
        expected = 8'h00;
        #1;
        check_q(expected);
        clk = 0;
        #1;
        check_q(expected);

        capture(8'hff);
        capture(8'h00);
        capture(8'haa);
        capture(8'h55);
        for (i = 0; i < 8; i = i + 1) begin
            capture(8'b00000001 << i);
            capture(~(8'b00000001 << i));
        end
        for (i = 0; i < 256; i = i + 1)
            capture(i[7:0]);
        capture(8'b10xz01zx);
        capture(8'h00);
        $display("PASS: eight positive-edge DFFs, %0d checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
