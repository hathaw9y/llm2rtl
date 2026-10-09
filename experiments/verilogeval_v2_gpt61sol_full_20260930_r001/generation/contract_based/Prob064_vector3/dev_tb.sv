module dev_tb;
    logic [4:0] a,b,c,d,e,f;
    wire [7:0] w,x,y,z;
    logic [31:0] rng = 32'h064abcde;
    integer checks = 0;
    TopModule dut (.a(a),.b(b),.c(c),.d(d),.e(e),.f(f),
                   .w(w),.x(x),.y(y),.z(z));

    task automatic check(input logic [29:0] stimulus);
        logic [31:0] expected;
        begin
            a = stimulus[29:25];
            b = stimulus[24:20];
            c = stimulus[19:15];
            d = stimulus[14:10];
            e = stimulus[9:5];
            f = stimulus[4:0];
            expected = (32'(a) << 27) | (32'(b) << 22) |
                       (32'(c) << 17) | (32'(d) << 12) |
                       (32'(e) << 7) | (32'(f) << 2) | 32'd3;
            #1;
            if (w !== expected[31:24] || x !== expected[23:16] ||
                y !== expected[15:8] || z !== expected[7:0])
                $fatal(1, "FAIL stimulus=%h outputs=%h expected=%h",
                       stimulus, {w,x,y,z}, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        check(30'b0);
        check(30'h3fffffff);
        check(30'h15555555);
        check(30'h2aaaaaaa);
        for (integer i=0; i<30; i=i+1) begin
            check(30'b1 << i);
            check(~(30'b1 << i));
        end
        for (integer i=0; i<1000; i=i+1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            check(rng[29:0]);
        end
        $display("PASS: %0d independent mapping checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
