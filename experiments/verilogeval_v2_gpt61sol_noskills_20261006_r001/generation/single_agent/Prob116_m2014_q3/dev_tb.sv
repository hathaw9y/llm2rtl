`timescale 1ns/1ps
module dev_tb;
    reg [4:1] x;
    wire f;
    integer value;
    integer checked = 0;
    reg expected;
    reg specified;

    TopModule dut (.x(x), .f(f));

    // Direct lookup of the original map, with row x[3]x[4]
    // and column x[1]x[2] encoded in ordinary binary order.
    task check_map;
        begin
            specified = 1'b1;
            case ({x[3], x[4], x[1], x[2]})
                4'b0001: expected = 1'b0;
                4'b0100: expected = 1'b0;
                4'b0110: expected = 1'b0;
                4'b0111: expected = 1'b1;
                4'b1000: expected = 1'b1;
                4'b1001: expected = 1'b1;
                4'b1011: expected = 1'b0;
                4'b1100: expected = 1'b1;
                4'b1101: expected = 1'b1;
                default: begin specified = 1'b0; expected = 1'bx; end
            endcase
            if (specified) begin
                if (f !== expected)
                    $fatal(1, "Map mismatch x=%b row=%b col=%b got=%b expected=%b",
                           x, {x[3],x[4]}, {x[1],x[2]}, f, expected);
                checked = checked + 1;
            end
        end
    endtask

    initial begin
        for (value = 0; value < 16; value = value + 1) begin
            x = value;
            #1;
            check_map;
        end
        if (checked != 9) $fatal(1, "Incorrect specified-cell coverage: %0d", checked);
        $display("PASS: all 16 inputs exercised, all 9 specified map cells verified");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
