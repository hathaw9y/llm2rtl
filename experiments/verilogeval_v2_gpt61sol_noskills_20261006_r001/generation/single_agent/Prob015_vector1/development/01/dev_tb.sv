`timescale 1ns/1ps
module dev_tb;
    reg [15:0] in;
    wire [7:0] out_hi, out_lo;
    integer value;
    TopModule dut (.in(in), .out_hi(out_hi), .out_lo(out_lo));

    task check_numeric(input integer word_value);
        begin
            in = word_value;
            #1;
            if (out_hi !== ((word_value / 256) % 256) ||
                out_lo !== (word_value % 256))
                $fatal(1, "Byte split mismatch for %h: hi=%h lo=%h", in, out_hi, out_lo);
        end
    endtask

    initial begin
        check_numeric(0);
        check_numeric(65535);
        check_numeric(255);
        check_numeric(256);
        check_numeric(16'hA55A);
        check_numeric(16'h5AA5);
        for (value = 0; value < 65536; value = value + 1)
            check_numeric(value);
        in = {8'hx, 8'h3C};
        #1;
        if (out_hi !== 8'hx || out_lo !== 8'h3C)
            $fatal(1, "Unknown upper byte propagation mismatch");
        in = {8'hC3, 8'hz};
        #1;
        if (out_hi !== 8'hC3 || out_lo !== 8'hz)
            $fatal(1, "High impedance lower byte propagation mismatch");
        $display("PASS exhaustive byte split and four-state propagation checks");
        $finish;
    end

    initial begin
        #70000;
        $fatal(1, "Testbench timeout");
    end
endmodule
