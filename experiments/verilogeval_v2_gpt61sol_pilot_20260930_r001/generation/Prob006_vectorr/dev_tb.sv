`timescale 1ns/1ps
module dev_tb;
    logic [7:0] in;
    wire [7:0] out;
    integer value, work_value, expected, bit_number;
    TopModule dut (.in(in), .out(out));
    initial begin
        for (value = 0; value < 256; value = value + 1) begin
            work_value = value;
            expected = 0;
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
                expected = expected * 2 + work_value % 2;
                work_value = work_value / 2;
            end
            in = value[7:0];
            #1;
            if (out !== expected[7:0])
                $fatal(1, "FAIL input=%h actual=%h expected=%h", in, out, expected[7:0]);
        end
        in = 8'bx10z01xz;
        #1;
        if (out !== 8'bzx10z01x) $fatal(1, "FAIL X/Z bit propagation");
        $display("PASS: 256 exhaustive binary vectors and X/Z propagation");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL timeout");
    end
endmodule
