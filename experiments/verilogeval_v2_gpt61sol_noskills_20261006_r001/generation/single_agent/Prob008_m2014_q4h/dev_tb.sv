`timescale 1ns/1ps
module dev_tb;
    reg in;
    wire out;
    TopModule dut (.in(in), .out(out));

    task check_value(input reg value);
        begin
            in = value;
            #1;
            if (out !== value)
                $fatal(1, "Combinational mismatch: in=%b out=%b", value, out);
        end
    endtask

    initial begin
        check_value(1'bx);
        check_value(1'b0);
        check_value(1'b1);
        check_value(1'b0);
        check_value(1'b1);
        check_value(1'bz);
        check_value(1'bx);
        check_value(1'b1);
        check_value(1'b0);
        $display("PASS combinational identity for 0, 1, X, and Z");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
