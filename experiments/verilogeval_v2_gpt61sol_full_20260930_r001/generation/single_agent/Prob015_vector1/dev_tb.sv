module dev_tb;
    logic [15:0] in;
    wire [7:0] out_hi, out_lo;
    integer value;
    TopModule dut (.in(in), .out_hi(out_hi), .out_lo(out_lo));
    initial begin
        for (value = 0; value < 65536; value = value + 1) begin
            in = 16'(value);
            #1;
            if (out_hi !== 8'(value / 256) || out_lo !== 8'(value % 256))
                $fatal(1, "FAIL input=%h hi=%h lo=%h", in, out_hi, out_lo);
        end
        $display("PASS: all 65536 binary inputs");
        $finish;
    end
    initial begin
        #70000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
