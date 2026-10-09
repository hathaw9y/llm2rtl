`timescale 1ns/1ps
module dev_tb;
    reg in;
    wire out;
    integer i;
    TopModule dut (.in(in), .out(out));

    task check_value(input reg value);
        begin
            in = value;
            #1;
            if (out !== value)
                $fatal(1, "Wire mismatch: in=%b out=%b", value, out);
        end
    endtask

    initial begin
        check_value(1'b0);
        check_value(1'b1);
        check_value(1'bx);
        check_value(1'bz);
        check_value(1'b1);
        check_value(1'b0);
        for (i = 0; i < 20; i = i + 1) begin
            check_value(1'b1);
            check_value(1'b0);
        end
        $display("PASS wire forwards all four logic values and repeated transitions");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Testbench timeout");
    end
endmodule
