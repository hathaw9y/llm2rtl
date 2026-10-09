module dev_tb;
    logic in1, in2, in3;
    logic out;
    logic expected;
    TopModule dut (.in1(in1), .in2(in2), .in3(in3), .out(out));
    initial begin
        for (int i = 0; i < 8; i++) begin
            {in1, in2, in3} = i[2:0];
            case (i)
                0, 3, 5, 6: expected = 1'b1;
                default: expected = 1'b0;
            endcase
            #1;
            if (out !== expected)
                $fatal(1, "FAIL inputs=%b%b%b expected=%b actual=%b", in1, in2, in3, expected, out);
        end
        $display("PASS: all 8 binary input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
