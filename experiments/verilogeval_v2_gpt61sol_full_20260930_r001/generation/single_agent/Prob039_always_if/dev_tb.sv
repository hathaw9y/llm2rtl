module dev_tb;
    logic a, b, sel_b1, sel_b2;
    wire out_assign, out_always;
    logic expected;
    integer i;

    TopModule dut (.*);

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            {a, b, sel_b1, sel_b2} = i[3:0];
            #1;
            expected = ((i & 3) == 3) ? b : a;
            if (out_assign !== expected || out_always !== expected)
                $fatal(1, "FAIL inputs=%b outputs=%b%b expected=%b",
                       {a,b,sel_b1,sel_b2}, out_assign, out_always, expected);
        end
        $display("PASS: all 16 binary input combinations");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
