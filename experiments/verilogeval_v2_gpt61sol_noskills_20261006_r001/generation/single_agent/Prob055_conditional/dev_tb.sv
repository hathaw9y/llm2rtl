`timescale 1ns/1ps
module dev_tb;
    reg [7:0] a, b, c, d;
    wire [7:0] min;
    integer checks = 0;
    integer i, j, position;
    reg [31:0] random_state = 32'h8ec51a37;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .min(min));

    task check_values(input integer va, vb, vc, vd);
        integer expected;
        begin
            a = va; b = vb; c = vc; d = vd;
            // Integer oracle uses a sequential scan independent of the DUT tree.
            expected = va;
            if (vb < expected) expected = vb;
            if (vc < expected) expected = vc;
            if (vd < expected) expected = vd;
            #1;
            if (min !== expected[7:0])
                $fatal(1, "minimum mismatch: inputs %0d %0d %0d %0d expected %0d got %0d", va, vb, vc, vd, expected, min);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_values(0, 0, 0, 0);
        check_values(255, 255, 255, 255);
        check_values(128, 127, 254, 255);
        check_values(255, 254, 128, 127);
        check_values(1, 0, 0, 255);
        check_values(255, 1, 0, 0);
        for (i = 0; i < 256; i = i + 1) begin
            check_values(i, i, i, i);
            for (position = 0; position < 4; position = position + 1) begin
                case (position)
                    0: check_values(i, 255, 255, 255);
                    1: check_values(255, i, 255, 255);
                    2: check_values(255, 255, i, 255);
                    3: check_values(255, 255, 255, i);
                endcase
            end
            for (j = 0; j < 256; j = j + 1) begin
                check_values(i, j, 255, 255);
                check_values(255, 255, i, j);
                check_values(i, 255, j, 255);
                check_values(255, i, 255, j);
            end
        end
        for (i = 0; i < 10000; i = i + 1) begin
            random_state = random_state ^ (random_state << 13);
            random_state = random_state ^ (random_state >> 17);
            random_state = random_state ^ (random_state << 5);
            check_values(random_state[7:0], random_state[15:8], random_state[23:16], random_state[31:24]);
        end
        $display("PASS: %0d unsigned minimum checks", checks);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Timeout");
    end
endmodule
