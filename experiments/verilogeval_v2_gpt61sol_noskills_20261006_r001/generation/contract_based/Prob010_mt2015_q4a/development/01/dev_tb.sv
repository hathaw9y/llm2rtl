`timescale 1ns/1ps
module dev_tb;
    reg x, y;
    wire z;
    reg expected;
    reg values [0:3];
    integer i, j;
    integer checked;
    TopModule dut (.x(x), .y(y), .z(z));

    initial begin
        #100;
        $fatal(1, "Timeout");
    end

    initial begin
        values[0] = 1'b0;
        values[1] = 1'b1;
        values[2] = 1'bx;
        values[3] = 1'bz;
        checked = 0;
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                x = values[i];
                y = values[j];
                // Independent table: x=0 always gives zero; x=1
                // gives one only for y=0; unknown x propagates.
                case (i)
                    0: expected = 1'b0;
                    1: begin
                        case (j)
                            0: expected = 1'b1;
                            1: expected = 1'b0;
                            default: expected = 1'bx;
                        endcase
                    end
                    default: expected = 1'bx;
                endcase
                #1;
                if (z !== expected)
                    $fatal(1, "Mismatch x=%b y=%b expected=%b actual=%b", x, y, expected, z);
                checked = checked + 1;
            end
        end
        $display("PASS: %0d combinational truth-table cases", checked);
        $finish;
    end
endmodule
