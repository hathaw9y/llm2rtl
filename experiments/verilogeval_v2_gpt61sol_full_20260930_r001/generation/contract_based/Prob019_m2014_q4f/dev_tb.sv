`timescale 1ns/1ps
module dev_tb;
    logic in1, in2;
    wire out;
    logic [3:0] expected;
    integer index;
    TopModule dut (.in1(in1), .in2(in2), .out(out));
    task automatic check(input integer vector_index);
        begin
            {in1, in2} = vector_index[1:0];
            #1;
            if (out !== expected[vector_index])
                $fatal(1, "FAIL: inputs=%b%b expected=%b actual=%b", in1, in2, expected[vector_index], out);
        end
    endtask
    initial begin
        expected = 4'b0100;
        for (index = 0; index < 4; index = index + 1) check(index);
        for (index = 3; index >= 0; index = index - 1) check(index);
        $display("PASS: all four binary input combinations checked twice");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: development test timeout");
    end
endmodule
