`timescale 1ns/1ps
module dev_tb;
    logic [15:0] in;
    wire [7:0] out_hi;
    wire [7:0] out_lo;
    integer value;
    logic [7:0] expected_hi;
    logic [7:0] expected_lo;

    TopModule dut (.in(in), .out_hi(out_hi), .out_lo(out_lo));

    initial begin
        for (value = 0; value < 65536; value = value + 1) begin
            in = 16'(value);
            expected_hi = 8'(value / 256);
            expected_lo = 8'(value % 256);
            #1;
            if ((out_hi !== expected_hi) || (out_lo !== expected_lo))
                $fatal(1, "FAIL input=%h hi=%h expected=%h lo=%h expected=%h",
                       in, out_hi, expected_hi, out_lo, expected_lo);
        end
        $display("PASS: all 65536 binary inputs checked");
        $finish;
    end

    initial begin
        #70000;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
