`timescale 1ns/1ps
module dev_tb;
    logic x, y;
    wire z;
    logic expected;
    integer i;
    TopModule dut (.x(x), .y(y), .z(z));

    task automatic check(input integer vector_index);
        begin
            case (vector_index)
                0: begin x = 1'b0; y = 1'b0; expected = 1'b0; end
                1: begin x = 1'b0; y = 1'b1; expected = 1'b0; end
                2: begin x = 1'b1; y = 1'b0; expected = 1'b1; end
                3: begin x = 1'b1; y = 1'b1; expected = 1'b0; end
                default: $fatal(1, "Invalid test vector");
            endcase
            #1;
            if (z !== expected)
                $fatal(1, "FAIL: x=%b y=%b z=%b expected=%b", x, y, z, expected);
        end
    endtask

    initial begin
        for (i = 0; i < 4; i = i + 1) check(i);
        for (i = 3; i >= 0; i = i - 1) check(i);
        $display("PASS: all four binary combinations, forward and reverse");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
