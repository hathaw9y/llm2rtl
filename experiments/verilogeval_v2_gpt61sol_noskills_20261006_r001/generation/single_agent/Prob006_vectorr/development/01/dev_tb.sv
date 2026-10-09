`timescale 1ns/1ps
module dev_tb;
    reg [7:0] in;
    wire [7:0] out;
    reg [7:0] expected;
    integer value;
    integer bit_index;
    TopModule dut (.in(in), .out(out));

    task check_value(input reg [7:0] stimulus);
        begin
            in = stimulus;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                expected[7-bit_index] = stimulus[bit_index];
            #1;
            if (out !== expected)
                $fatal(1, "input=%b expected=%b actual=%b", in, expected, out);
        end
    endtask

    initial begin
        check_value(8'h00);
        check_value(8'hff);
        check_value(8'h01);
        check_value(8'h80);
        check_value(8'h55);
        check_value(8'haa);
        for (value = 0; value < 256; value = value + 1)
            check_value(value[7:0]);
        check_value(8'bx0011010);
        check_value(8'b10z01001);
        check_value(8'bxxxxxxxx);
        check_value(8'bzzzzzzzz);
        $display("PASS: all 256 binary inputs, directed cases, and X/Z propagation");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
