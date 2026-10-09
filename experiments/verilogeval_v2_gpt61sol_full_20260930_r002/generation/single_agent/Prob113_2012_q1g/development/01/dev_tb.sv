`timescale 1ns/1ps
module dev_tb;
    logic [3:0] x;
    wire f;
    logic [3:0] row_values;
    logic expected;
    integer i;
    TopModule dut (.x(x), .f(f));

    // Numeric column indices are 00, 01, 10, 11; the printed
    // Karnaugh map uses Gray order 00, 01, 11, 10.
    function automatic logic oracle(input logic [3:0] value);
        logic [3:0] cells;
        begin
            case ({value[2], value[3]})
                2'b00: cells = 4'b0101;
                2'b01: cells = 4'b0000;
                2'b11: cells = 4'b1011;
                2'b10: cells = 4'b0111;
                default: cells = 4'bxxxx;
            endcase
            oracle = cells[{value[0], value[1]}];
        end
    endfunction

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            x = i[3:0];
            #1;
            expected = oracle(x);
            if (f !== expected)
                $fatal(1, "x=%b expected=%b actual=%b", x, expected, f);
        end
        // Repeat in reverse order to check combinational updates.
        for (i = 15; i >= 0; i = i - 1) begin
            x = i[3:0];
            #1;
            expected = oracle(x);
            if (f !== expected)
                $fatal(1, "reverse x=%b expected=%b actual=%b", x, expected, f);
        end
        $display("PASS: all 16 Karnaugh-map cells checked in both orders");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
