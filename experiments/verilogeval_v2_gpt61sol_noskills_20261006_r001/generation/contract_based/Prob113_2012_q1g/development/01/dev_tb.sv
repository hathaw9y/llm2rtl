`timescale 1ns/1ps
module dev_tb;
    reg [3:0] x;
    wire f;
    integer i;
    integer checks = 0;
    TopModule dut (.x(x), .f(f));

    // Original map columns 00,01,11,10 are converted to binary
    // index order 00,01,10,11; bit zero represents column 00.
    function automatic map_value(input [3:0] value);
        reg [3:0] row;
        begin
            case ({value[2], value[3]})
                2'b00: row = 4'b0101; // Original row: 1 0 0 1
                2'b01: row = 4'b0000; // Original row: 0 0 0 0
                2'b11: row = 4'b1011; // Original row: 1 1 1 0
                2'b10: row = 4'b0111; // Original row: 1 1 0 1
                default: row = 4'bxxxx;
            endcase
            map_value = row[{value[0], value[1]}];
        end
    endfunction

    task automatic check_input(input [3:0] value);
        reg expected;
        begin
            x = value;
            expected = map_value(value);
            #1;
            if (f !== expected)
                $fatal(1, "Mismatch x=%b: expected %b got %b", x, expected, f);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (i = 0; i < 16; i = i + 1) check_input(i[3:0]);
        for (i = 15; i >= 0; i = i - 1) check_input(i[3:0]);
        $display("PASS: %0d comparisons against original Karnaugh map", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
