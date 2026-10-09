`timescale 1ns/1ps
module dev_tb;
    logic in;
    wire out;
    TopModule dut (.in(in), .out(out));

    task automatic check_value(input logic stimulus, input logic expected);
        in = stimulus;
        #1;
        if (out !== expected)
            $fatal(1, "NOT mismatch: in=%b expected=%b actual=%b", in, expected, out);
    endtask

    initial begin
        check_value(1'b0, 1'b1);
        check_value(1'b1, 1'b0);
        check_value(1'b1, 1'b0);
        check_value(1'b0, 1'b1);
        check_value(1'bx, 1'bx);
        check_value(1'bz, 1'bx);
        check_value(1'b0, 1'b1);
        check_value(1'b1, 1'b0);
        $display("PASS NOT gate directed and four-state checks");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
