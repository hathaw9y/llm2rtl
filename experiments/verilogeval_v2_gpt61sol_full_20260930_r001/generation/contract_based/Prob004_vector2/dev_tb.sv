`timescale 1ns/1ps
module dev_tb;
    logic [31:0] in;
    wire [31:0] out;
    logic [31:0] random_state;
    integer checks = 0;
    TopModule dut (.in(in), .out(out));

    task automatic check(input logic [31:0] value);
        logic [31:0] expected;
        integer bit_index;
        begin
            for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1)
                expected[(3 - bit_index / 8) * 8 + bit_index % 8] = value[bit_index];
            in = value;
            #1;
            if (out !== expected)
                $fatal(1, "FAIL input=%h expected=%h actual=%h", value, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check(32'h00000000);
        check(32'hffffffff);
        check(32'h12345678);
        check(32'haaaaaaaa);
        check(32'h55555555);
        for (integer index = 0; index < 32; index = index + 1) begin
            check(32'h00000001 << index);
            check(~(32'h00000001 << index));
        end
        random_state = 32'h1a2b3c4d;
        for (integer index = 0; index < 1000; index = index + 1) begin
            random_state = random_state ^ (random_state << 13);
            random_state = random_state ^ (random_state >> 17);
            random_state = random_state ^ (random_state << 5);
            check(random_state);
        end
        $display("PASS: %0d byte-reversal checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "FAIL: development simulation timeout");
    end
endmodule
