`timescale 1ns/1ps
module dev_tb;
    logic [7:0] a, b;
    wire [7:0] s;
    wire overflow;
    integer i, j;
    integer checks = 0;

    TopModule dut (.a(a), .b(b), .s(s), .overflow(overflow));

    task automatic check_pair(input integer a_code, input integer b_code);
        integer signed_a, signed_b, mathematical_sum;
        logic [7:0] expected_s;
        logic expected_overflow;
        begin
            a = a_code[7:0];
            b = b_code[7:0];
            signed_a = (a_code >= 128) ? a_code - 256 : a_code;
            signed_b = (b_code >= 128) ? b_code - 256 : b_code;
            mathematical_sum = signed_a + signed_b;
            expected_s = mathematical_sum[7:0];
            expected_overflow = (mathematical_sum < -128) || (mathematical_sum > 127);
            #1;
            if (s !== expected_s || overflow !== expected_overflow)
                $fatal(1, "a=%0d b=%0d sum=%0d: s=%h expected=%h overflow=%b expected=%b",
                       signed_a, signed_b, mathematical_sum, s, expected_s,
                       overflow, expected_overflow);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_pair(0, 0);
        check_pair(127, 0);
        check_pair(127, 1);
        check_pair(127, 127);
        check_pair(128, 0);
        check_pair(128, 255);
        check_pair(128, 128);
        check_pair(128, 127);
        check_pair(255, 1);
        check_pair(255, 255);
        for (i = 0; i < 256; i = i + 1)
            for (j = 0; j < 256; j = j + 1)
                check_pair(i, j);
        $display("PASS: %0d signed addition and overflow checks", checks);
        $finish;
    end

    initial begin
        #70000;
        $fatal(1, "Timeout before exhaustive verification completed");
    end
endmodule
