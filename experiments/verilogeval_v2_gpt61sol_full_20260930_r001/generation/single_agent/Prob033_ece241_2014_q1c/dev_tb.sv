`timescale 1ns/1ps
module dev_tb;
    logic [7:0] a, b;
    wire [7:0] s;
    wire overflow;
    integer ia, ib;
    integer signed_a, signed_b, expected_sum;
    logic [7:0] expected_s;
    logic expected_overflow;
    TopModule dut (.a(a), .b(b), .s(s), .overflow(overflow));
    initial begin
        for (ia = 0; ia < 256; ia = ia + 1) begin
            for (ib = 0; ib < 256; ib = ib + 1) begin
                a = ia[7:0];
                b = ib[7:0];
                signed_a = (ia >= 128) ? ia - 256 : ia;
                signed_b = (ib >= 128) ? ib - 256 : ib;
                expected_sum = signed_a + signed_b;
                expected_s = expected_sum[7:0];
                expected_overflow = (expected_sum < -128) || (expected_sum > 127);
                #1;
                if ((s !== expected_s) || (overflow !== expected_overflow))
                    $fatal(1, "FAIL a=%0d b=%0d s=%h overflow=%b expected_s=%h expected_overflow=%b", signed_a, signed_b, s, overflow, expected_s, expected_overflow);
            end
        end
        $display("PASS: all 65536 input pairs");
        $finish;
    end
    initial begin
        #70000;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
