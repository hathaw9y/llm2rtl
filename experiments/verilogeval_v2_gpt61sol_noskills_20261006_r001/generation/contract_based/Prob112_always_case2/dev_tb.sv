`timescale 1ns/1ps
module dev_tb;
    reg [3:0] in;
    wire [1:0] pos;
    reg [1:0] expected [0:15];
    integer i;
    integer checks;
    TopModule dut (.in(in), .pos(pos));

    task check_input;
        input integer value;
        begin
            in = value;
            #1;
            if (pos !== expected[value])
                $fatal(1, "input=%b expected=%0d actual=%b", in, expected[value], pos);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Ascending index priority established by the original 10010000 example.
        expected[0] = 0;  expected[1] = 0;
        expected[2] = 1;  expected[3] = 0;
        expected[4] = 2;  expected[5] = 0;
        expected[6] = 1;  expected[7] = 0;
        expected[8] = 3;  expected[9] = 0;
        expected[10] = 1; expected[11] = 0;
        expected[12] = 2; expected[13] = 0;
        expected[14] = 1; expected[15] = 0;
        checks = 0;
        for (i = 0; i < 16; i = i + 1)
            check_input(i);
        for (i = 15; i >= 0; i = i - 1)
            check_input(i);
        $display("PASS all 16 binary inputs checked in both transition orders (%0d checks)", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
