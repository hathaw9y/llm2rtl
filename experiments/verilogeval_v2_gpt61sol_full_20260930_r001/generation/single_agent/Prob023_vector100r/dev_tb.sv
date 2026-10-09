module dev_tb;
    logic [99:0] in;
    wire [99:0] out;
    logic [99:0] expected;
    integer tests = 0;
    TopModule dut (.in(in), .out(out));

    task automatic check(input logic [99:0] value);
        in = value;
        for (integer j = 0; j < 100; j = j + 1)
            expected[99-j] = value[j];
        #1;
        if (out !== expected)
            $fatal(1, "FAIL input=%h expected=%h actual=%h", in, expected, out);
        tests = tests + 1;
    endtask

    initial begin
        check('0);
        check('1);
        for (integer k = 0; k < 100; k = k + 1) begin
            check(100'b1 << k);
            check(~(100'b1 << k));
        end
        for (integer k = 0; k < 1000; k = k + 1)
            check({$urandom, $urandom, $urandom, $urandom});
        check({50{2'b10}});
        check({50{2'b01}});
        check('x);
        check('z);
        $display("PASS: %0d bit-reversal checks", tests);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "FAIL timeout");
    end
endmodule
