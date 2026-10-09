module dev_tb;
    logic [99:0] in;
    wire out_and, out_or, out_xor;
    integer checks = 0;
    TopModule dut (.in(in), .out_and(out_and), .out_or(out_or), .out_xor(out_xor));
    task automatic check(input logic [99:0] value);
        logic expected_and, expected_or, expected_xor;
        begin
            expected_and = 1'b1;
            expected_or = 1'b0;
            expected_xor = 1'b0;
            for (integer j = 0; j < 100; j = j + 1) begin
                expected_and = expected_and & value[j];
                expected_or = expected_or | value[j];
                expected_xor = expected_xor ^ value[j];
            end
            in = value;
            #1;
            if ({out_and, out_or, out_xor} !== {expected_and, expected_or, expected_xor})
                $fatal(1, "FAIL input=%h output=%b%b%b", in, out_and, out_or, out_xor);
            checks = checks + 1;
        end
    endtask
    initial begin
        check(100'b0);
        check({100{1'b1}});
        for (integer i = 0; i < 100; i = i + 1) begin
            check(100'b1 << i);
            check(~(100'b1 << i));
        end
        for (integer i = 0; i < 1000; i = i + 1)
            check({$urandom, $urandom, $urandom, $urandom});
        check({100{1'bx}});
        check({100{1'bz}});
        $display("PASS: %0d vectors", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL timeout");
    end
endmodule
