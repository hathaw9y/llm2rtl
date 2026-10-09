module dev_tb;
    logic in1, in2;
    wire out;
    TopModule dut (.in1(in1), .in2(in2), .out(out));
    initial begin
        for (integer i = 0; i < 4; i = i + 1) begin
            {in1, in2} = i[1:0];
            #1;
            if (out !== (i == 2))
                $fatal(1, "FAIL inputs=%b%b out=%b", in1, in2, out);
        end
        $display("PASS: all four binary input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
