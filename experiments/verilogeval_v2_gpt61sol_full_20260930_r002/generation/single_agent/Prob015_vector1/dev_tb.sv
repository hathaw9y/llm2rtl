`timescale 1ns/1ps
module dev_tb;
    logic [15:0] in;
    wire [7:0] out_hi, out_lo;
    integer value;
    logic [7:0] expected_hi, expected_lo;

    TopModule dut (.in(in), .out_hi(out_hi), .out_lo(out_lo));

    initial begin
        #100000;
        $fatal(1, "Timeout");
    end

    initial begin
        // Exhaustive numeric oracle: upper byte is quotient, lower is remainder.
        for (value = 0; value < 65536; value = value + 1) begin
            in = value;
            expected_hi = value / 256;
            expected_lo = value % 256;
            #1;
            if (out_hi !== expected_hi || out_lo !== expected_lo)
                $fatal(1, "Input %h: got %h/%h expected %h/%h",
                       in, out_hi, out_lo, expected_hi, expected_lo);
        end
        in = 16'bxxxx_xxxx_1010_0101;
        #1;
        if (out_hi !== 8'bxxxxxxxx || out_lo !== 8'ha5)
            $fatal(1, "Upper unknown propagation failed");
        in = 16'b0101_1010_zzzz_zzzz;
        #1;
        if (out_hi !== 8'h5a || out_lo !== 8'bzzzzzzzz)
            $fatal(1, "Lower high impedance propagation failed");
        $display("PASS exhaustive byte split and four-state propagation");
        $finish;
    end
endmodule
