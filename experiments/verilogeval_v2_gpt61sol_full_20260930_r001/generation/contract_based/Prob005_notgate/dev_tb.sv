module dev_tb;
    logic in;
    wire out;
    TopModule dut (.in(in), .out(out));

    task automatic check(input logic stimulus, input logic expected);
        in = stimulus;
        #1;
        if (out !== expected)
            $fatal(1, "FAIL: in=%b out=%b expected=%b", in, out, expected);
    endtask

    initial begin
        check(1'b0, 1'b1);
        check(1'b1, 1'b0);
        check(1'b0, 1'b1);
        check(1'b1, 1'b0);
        $display("PASS: NOT gate truth table and repeated transitions (4 checks)");
        $finish;
    end

    initial begin
        #20;
        $fatal(1, "FAIL: development simulation timeout");
    end
endmodule
