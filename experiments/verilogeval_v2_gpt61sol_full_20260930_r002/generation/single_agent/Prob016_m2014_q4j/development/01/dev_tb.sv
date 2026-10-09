`timescale 1ns/1ps
module dev_tb;
    logic [3:0] x;
    logic [3:0] y;
    wire [4:0] sum;
    integer x_value;
    integer y_value;
    integer checks = 0;
    logic [4:0] expected;

    TopModule dut (.x(x), .y(y), .sum(sum));

    initial begin
        for (x_value = 0; x_value < 16; x_value = x_value + 1) begin
            for (y_value = 0; y_value < 16; y_value = y_value + 1) begin
                x = x_value[3:0];
                y = y_value[3:0];
                expected = {1'b0, x} + {1'b0, y};
                #1;
                if (sum !== expected)
                    $fatal(1, "x=%0d y=%0d expected=%0d actual=%0d", x, y, expected, sum);
                checks = checks + 1;
            end
        end
        $display("PASS: all %0d four-bit input pairs, including overflow and carry boundaries", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
