`timescale 1ns/1ps
module dev_tb;
    reg in;
    wire out;
    TopModule dut (.in(in), .out(out));

    task automatic check(input reg stimulus, input reg expected);
        begin
            in = stimulus;
            #1;
            if (out !== expected)
                $fatal(1, "NOT gate mismatch: in=%b expected=%b actual=%b", in, expected, out);
        end
    endtask

    initial begin
        check(1'b0, 1'b1);
        check(1'b1, 1'b0);
        check(1'b0, 1'b1);
        check(1'b1, 1'b0);
        check(1'bx, 1'bx);
        check(1'bz, 1'bx);
        check(1'b0, 1'b1);
        $display("PASS: NOT gate directed and four-state checks");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Testbench timeout");
    end
endmodule
