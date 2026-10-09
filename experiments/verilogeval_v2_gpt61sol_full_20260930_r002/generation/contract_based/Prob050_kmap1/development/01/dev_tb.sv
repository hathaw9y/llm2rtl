`timescale 1ns/1ps
module dev_tb;
    logic a, b, c;
    wire out;
    integer i;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .c(c), .out(out));

    // Entries transcribed from the original map, indexed by {a,b,c}.
    function automatic logic map_expected(input logic [2:0] abc);
        case (abc)
            3'b000: map_expected = 1'b0;
            3'b001: map_expected = 1'b1;
            3'b010: map_expected = 1'b1;
            3'b011: map_expected = 1'b1;
            3'b100: map_expected = 1'b1;
            3'b101: map_expected = 1'b1;
            3'b110: map_expected = 1'b1;
            3'b111: map_expected = 1'b1;
            default: map_expected = 1'bx;
        endcase
    endfunction

    task automatic check_entry(input logic [2:0] abc);
        logic expected;
        begin
            {a,b,c} = abc;
            expected = map_expected(abc);
            #1;
            if (out !== expected)
                $fatal(1, "Map mismatch abc=%b expected=%b actual=%b", abc, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (i = 0; i < 8; i = i + 1)
            check_entry(i[2:0]);
        for (i = 7; i >= 0; i = i - 1)
            check_entry(i[2:0]);
        $display("PASS: all Karnaugh map entries checked in both directions (%0d checks)", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Development test timeout");
    end
endmodule
