`timescale 1ns/1ps
module dev_tb;
    logic in;
    wire out;
    TopModule dut (.in(in), .out(out));

    task automatic check_value(input logic value);
        in = value;
        #1;
        if (out !== value)
            $fatal(1, "Wire mismatch: in=%b out=%b expected=%b", in, out, value);
    endtask

    initial begin
        #1;
        if (out !== 1'bx)
            $fatal(1, "Undriven input should propagate X: out=%b", out);
        check_value(1'b0);
        check_value(1'b1);
        check_value(1'b0);
        check_value(1'b1);
        check_value(1'bx);
        check_value(1'b0);
        check_value(1'bz);
        check_value(1'b1);
        check_value(1'bz);
        check_value(1'bx);
        check_value(1'b0);
        $display("PASS wire propagation checks");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
