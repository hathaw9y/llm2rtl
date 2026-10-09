`timescale 1ns/1ps
module dev_tb;
    logic [15:0] in;
    wire [7:0] out_hi, out_lo;
    integer value;
    logic [7:0] expected_hi, expected_lo;

    TopModule dut (.in(in), .out_hi(out_hi), .out_lo(out_lo));

    task automatic check_bits(input logic [15:0] stimulus,
                              input logic [7:0] hi,
                              input logic [7:0] lo);
        begin
            in = stimulus;
            #1;
            if (out_hi !== hi || out_lo !== lo)
                $fatal(1, "in=%h hi=%h expected=%h lo=%h expected=%h",
                       in, out_hi, hi, out_lo, lo);
        end
    endtask

    initial begin
        check_bits(16'h1234, 8'h12, 8'h34);
        check_bits(16'hff00, 8'hff, 8'h00);
        check_bits(16'h00ff, 8'h00, 8'hff);
        for (value = 0; value < 65536; value = value + 1) begin
            expected_hi = value / 256;
            expected_lo = value % 256;
            check_bits(value[15:0], expected_hi, expected_lo);
        end
        check_bits(16'hxxxx, 8'hxx, 8'hxx);
        check_bits(16'hzzzz, 8'hzz, 8'hzz);
        check_bits(16'b10xz0101_01zx1010, 8'b10xz0101, 8'b01zx1010);
        $display("PASS exhaustive byte split and four-state propagation");
        $finish;
    end

    initial begin
        #70000;
        $fatal(1, "Timeout");
    end
endmodule
