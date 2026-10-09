module dev_tb;
    logic [4:0] a, b, c, d, e, f;
    wire [7:0] w, x, y, z;
    logic [29:0] stimulus;
    logic [31:0] expected;
    integer i;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .e(e), .f(f),
                   .w(w), .x(x), .y(y), .z(z));
    task automatic check(input logic [29:0] value);
        begin
            a = value[29:25];
            b = value[24:20];
            c = value[19:15];
            d = value[14:10];
            e = value[9:5];
            f = value[4:0];
            expected = 32'h00000003;
            for (integer bit_index = 0; bit_index < 30; bit_index++)
                expected[bit_index + 2] = value[bit_index];
            #1;
            if ({w, x, y, z} !== expected)
                $fatal(1, "FAIL input=%h actual=%h expected=%h", value, {w,x,y,z}, expected);
            checks = checks + 1;
        end
    endtask
    initial begin
        check(30'b0);
        check(30'h3fffffff);
        check(30'h15555555);
        check(30'h2aaaaaaa);
        for (i = 0; i < 30; i = i + 1) begin
            stimulus = 30'b1 << i;
            check(stimulus);
            check(~stimulus);
        end
        for (i = 0; i < 1000; i = i + 1)
            check($urandom);
        $display("PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "FAIL: timeout");
    end
endmodule
