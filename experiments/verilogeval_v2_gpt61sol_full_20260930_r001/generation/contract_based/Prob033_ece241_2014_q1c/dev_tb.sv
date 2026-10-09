`timescale 1ns/1ps
module dev_tb;
    logic [7:0] a, b;
    wire [7:0] s;
    wire overflow;
    integer ai, bi, signed_a, signed_b, exact_sum, checked;
    logic [7:0] expected_s;
    logic expected_overflow;
    TopModule dut (.a(a), .b(b), .s(s), .overflow(overflow));
    initial begin
        checked = 0;
        for (ai = 0; ai < 256; ai = ai + 1) begin
            for (bi = 0; bi < 256; bi = bi + 1) begin
                a = ai[7:0];
                b = bi[7:0];
                signed_a = (ai >= 128) ? ai - 256 : ai;
                signed_b = (bi >= 128) ? bi - 256 : bi;
                exact_sum = signed_a + signed_b;
                expected_s = exact_sum[7:0];
                expected_overflow = (exact_sum < -128) || (exact_sum > 127);
                #1;
                if ((s !== expected_s) || (overflow !== expected_overflow))
                    $fatal(1, "FAIL a=%0d b=%0d s=%h expected=%h overflow=%b expected=%b", signed_a, signed_b, s, expected_s, overflow, expected_overflow);
                checked = checked + 1;
            end
        end
        $display("PASS: %0d exhaustive input pairs", checked);
        $finish;
    end
    initial begin
        #70000;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
