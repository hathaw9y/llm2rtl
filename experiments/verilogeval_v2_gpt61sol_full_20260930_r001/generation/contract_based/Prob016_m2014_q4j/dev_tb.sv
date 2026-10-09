module dev_tb;
    logic [3:0] x, y;
    wire [4:0] sum;
    logic [4:0] expected;
    integer cases_checked;
    TopModule dut (.x(x), .y(y), .sum(sum));

    initial begin
        cases_checked = 0;
        for (integer a = 0; a < 16; a = a + 1) begin
            for (integer b = 0; b < 16; b = b + 1) begin
                x = a[3:0];
                y = b[3:0];
                expected = 5'(a + b);
                #1;
                if (sum !== expected)
                    $fatal(1, "FAIL x=%0d y=%0d actual=%0d expected=%0d", x, y, sum, expected);
                cases_checked = cases_checked + 1;
            end
        end
        $display("PASS: %0d input pairs checked", cases_checked);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
