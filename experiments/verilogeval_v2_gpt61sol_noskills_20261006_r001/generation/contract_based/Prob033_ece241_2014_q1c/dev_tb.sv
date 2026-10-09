`timescale 1ns/1ps
module dev_tb;
    reg [7:0] a, b;
    wire [7:0] s;
    wire overflow;
    integer i, j;
    integer checks = 0;

    TopModule dut (.a(a), .b(b), .s(s), .overflow(overflow));

    task check_pair(input integer av, input integer bv);
        integer signed_a, signed_b, total;
        reg [7:0] expected_s;
        reg expected_overflow;
        begin
            a = av;
            b = bv;
            signed_a = (av >= 128) ? av - 256 : av;
            signed_b = (bv >= 128) ? bv - 256 : bv;
            total = signed_a + signed_b;
            expected_s = total;
            expected_overflow = (total < -128) || (total > 127);
            #1;
            if (s !== expected_s || overflow !== expected_overflow)
                $fatal(1, "a=%0d b=%0d sum=%0d: s=%h expected=%h overflow=%b expected=%b",
                       signed_a, signed_b, total, s, expected_s, overflow, expected_overflow);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_pair(0, 0);
        check_pair(127, 0);
        check_pair(127, 1);
        check_pair(128, 0);
        check_pair(128, 255);
        check_pair(128, 128);
        check_pair(127, 127);
        check_pair(255, 1);
        check_pair(127, 128);
        for (i = 0; i < 256; i = i + 1)
            for (j = 0; j < 256; j = j + 1)
                check_pair(i, j);
        $display("PASS: %0d directed and exhaustive signed-addition checks", checks);
        $finish;
    end

    initial begin
        #70000;
        $fatal(1, "Timeout");
    end
endmodule
