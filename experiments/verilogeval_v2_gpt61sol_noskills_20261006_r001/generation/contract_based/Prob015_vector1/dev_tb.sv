`timescale 1ns/1ps
module dev_tb;
    reg [15:0] in;
    wire [7:0] out_hi, out_lo;
    integer value;
    integer checks = 0;
    TopModule dut (.in(in), .out_hi(out_hi), .out_lo(out_lo));

    task check_binary(input integer stimulus);
        reg [7:0] expected_hi, expected_lo;
        begin
            expected_hi = stimulus / 256;
            expected_lo = stimulus % 256;
            in = stimulus;
            #1;
            if (out_hi !== expected_hi || out_lo !== expected_lo)
                $fatal(1, "Input %h: hi=%h lo=%h expected hi=%h lo=%h",
                       in, out_hi, out_lo, expected_hi, expected_lo);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_binary(0);
        check_binary(65535);
        check_binary(255);
        check_binary(256);
        check_binary(65280);
        check_binary(16'h55aa);
        check_binary(16'haa55);
        for (value = 0; value < 65536; value = value + 1)
            check_binary(value);
        in = 16'bxxxxxxxx01011010;
        #1;
        if (out_hi !== 8'bxxxxxxxx || out_lo !== 8'h5a)
            $fatal(1, "Upper unknown byte propagation failed");
        in = 16'b10100101zzzzzzzz;
        #1;
        if (out_hi !== 8'ha5 || out_lo !== 8'bzzzzzzzz)
            $fatal(1, "Lower high impedance byte propagation failed");
        in = 16'bxz0101zx10zx01xz;
        #1;
        if (out_hi !== 8'bxz0101zx || out_lo !== 8'b10zx01xz)
            $fatal(1, "Mixed four-state bit ordering failed");
        $display("PASS: %0d binary byte-split checks and 3 four-state checks", checks);
        $finish;
    end

    initial begin
        #70000;
        $fatal(1, "Timeout");
    end
endmodule
