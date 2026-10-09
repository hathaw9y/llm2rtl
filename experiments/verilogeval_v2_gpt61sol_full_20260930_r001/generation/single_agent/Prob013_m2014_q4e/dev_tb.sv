`timescale 1ns/1ps
module dev_tb;
    logic in1, in2;
    wire out;
    TopModule dut (.in1(in1), .in2(in2), .out(out));
    initial begin
        for (int i = 0; i < 4; i++) begin
            {in1, in2} = i[1:0];
            #1;
            if (out !== (i == 0))
                $fatal(1, "FAIL: inputs=%b%b out=%b", in1, in2, out);
        end
        $display("PASS: all four NOR truth-table cases");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
