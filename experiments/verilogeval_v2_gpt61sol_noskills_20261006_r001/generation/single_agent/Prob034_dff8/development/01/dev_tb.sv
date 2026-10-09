`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg [7:0] d = 0;
    wire [7:0] q;
    reg [7:0] expected;
    integer i;
    integer checks = 0;
    TopModule dut (.clk(clk), .d(d), .q(q));

    task check_q(input [7:0] value);
        begin
            if (q !== value)
                $fatal(1, "q mismatch: expected %h, observed %h", value, q);
            checks = checks + 1;
        end
    endtask

    task capture_and_hold(input [7:0] value);
        begin
            d = value;
            #2;
            check_q(expected);
            clk = 1;
            #1;
            expected = value;
            check_q(expected);
            d = ~value;
            #2;
            check_q(expected);
            clk = 0;
            #1;
            check_q(expected);
        end
    endtask

    initial begin
        // No reset or initialization is required by the specification.
        // Establish a known sampled value before comparing output data.
        #2;
        clk = 1;
        #1;
        expected = 8'h00;
        check_q(expected);
        clk = 0;
        #1;
        capture_and_hold(8'hff);
        capture_and_hold(8'h00);
        capture_and_hold(8'haa);
        capture_and_hold(8'h55);
        for (i = 0; i < 8; i = i + 1) begin
            capture_and_hold(8'h01 << i);
            capture_and_hold(~(8'h01 << i));
        end
        for (i = 0; i < 256; i = i + 1)
            capture_and_hold(i[7:0]);
        $display("PASS: positive-edge capture and hold verified (%0d checks)", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
