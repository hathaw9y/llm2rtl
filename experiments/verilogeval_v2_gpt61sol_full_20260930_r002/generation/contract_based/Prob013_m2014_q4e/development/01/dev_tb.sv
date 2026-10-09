`timescale 1ns/1ps
module dev_tb;
    logic in1, in2;
    wire out;
    integer checks = 0;
    TopModule dut (.in1(in1), .in2(in2), .out(out));

    task automatic check_nor(input logic a, input logic b, input logic expected);
        begin
            in1 = a;
            in2 = b;
            #1;
            if (out !== expected)
                $fatal(1, "NOR mismatch: in1=%b in2=%b expected=%b actual=%b", a, b, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Explicit original NOR truth table, followed by single-input transitions.
        check_nor(1'b0, 1'b0, 1'b1);
        check_nor(1'b0, 1'b1, 1'b0);
        check_nor(1'b1, 1'b0, 1'b0);
        check_nor(1'b1, 1'b1, 1'b0);
        check_nor(1'b0, 1'b1, 1'b0);
        check_nor(1'b0, 1'b0, 1'b1);
        check_nor(1'b1, 1'b0, 1'b0);
        check_nor(1'b0, 1'b0, 1'b1);
        check_nor(1'b0, 1'b0, 1'b1);
        $display("PASS NOR truth table and transitions (%0d checks)", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Development test timeout");
    end
endmodule
