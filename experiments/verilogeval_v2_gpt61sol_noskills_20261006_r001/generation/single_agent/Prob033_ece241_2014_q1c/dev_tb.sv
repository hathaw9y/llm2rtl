`timescale 1ns/1ps
module dev_tb;
    reg [7:0] a, b;
    wire [7:0] s;
    wire overflow;
    integer i, j;
    integer signed_a, signed_b, total;
    reg [7:0] expected_s;
    reg expected_overflow;
    TopModule dut(.a(a), .b(b), .s(s), .overflow(overflow));

    task check_pair(input integer aa, input integer bb);
        begin
            a = aa;
            b = bb;
            signed_a = (aa >= 128) ? aa - 256 : aa;
            signed_b = (bb >= 128) ? bb - 256 : bb;
            total = signed_a + signed_b;
            expected_s = total;
            expected_overflow = (total < -128) || (total > 127);
            #1;
            if (s !== expected_s || overflow !== expected_overflow)
                $fatal(1, "a=%0d b=%0d total=%0d: s=%h expected=%h overflow=%b expected=%b",
                       signed_a, signed_b, total, s, expected_s, overflow, expected_overflow);
        end
    endtask

    initial begin
        check_pair(0, 0);
        check_pair(127, 1);
        check_pair(128, 255);
        check_pair(127, 127);
        check_pair(128, 128);
        check_pair(128, 127);
        check_pair(255, 1);
        check_pair(127, 0);
        check_pair(128, 0);
        for (i = 0; i < 256; i = i + 1)
            for (j = 0; j < 256; j = j + 1)
                check_pair(i, j);
        $display("PASS: directed boundaries and all 65536 input pairs");
        $finish;
    end

    initial begin
        #70000;
        $fatal(1, "Development test timeout");
    end
endmodule
