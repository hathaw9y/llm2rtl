module dev_tb;
    logic c, d;
    logic [3:0] mux_in;
    logic [3:0] expected;
    integer cd, ab;
    TopModule dut (.c(c), .d(d), .mux_in(mux_in));
    initial begin
        for (cd = 0; cd < 4; cd = cd + 1) begin
            {c,d} = 2'(cd);
            case (cd)
                0: expected = 4'b0100;
                1: expected = 4'b0001;
                2: expected = 4'b0101;
                3: expected = 4'b1101;
            endcase
            #1;
            for (ab = 0; ab < 4; ab = ab + 1) begin
                if (mux_in[ab] !== expected[ab])
                    $fatal(1, "FAIL cd=%0d ab=%0d actual=%b expected=%b", cd, ab, mux_in[ab], expected[ab]);
            end
        end
        $display("PASS: all 16 K-map entries");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
