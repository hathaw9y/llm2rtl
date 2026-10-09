`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire out;
    integer i;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out));

    // Literal transcription of original map, indexed by {a,b,c,d}.
    // X here marks only the three unconstrained map cells.
    function automatic logic map_expected(input logic [3:0] bits);
        case (bits)
            4'b0000: map_expected = 1'b0;
            4'b0001: map_expected = 1'b0;
            4'b0010: map_expected = 1'b1;
            4'b0011: map_expected = 1'b1;
            4'b0100: map_expected = 1'bx;
            4'b0101: map_expected = 1'b0;
            4'b0110: map_expected = 1'b0;
            4'b0111: map_expected = 1'b0;
            4'b1000: map_expected = 1'b1;
            4'b1001: map_expected = 1'bx;
            4'b1010: map_expected = 1'b1;
            4'b1011: map_expected = 1'b1;
            4'b1100: map_expected = 1'b1;
            4'b1101: map_expected = 1'bx;
            4'b1110: map_expected = 1'b1;
            4'b1111: map_expected = 1'b1;
            default: map_expected = 1'bx;
        endcase
    endfunction

    task automatic check_input(input logic [3:0] bits);
        logic expected;
        begin
            {a,b,c,d} = bits;
            expected = map_expected(bits);
            #1;
            if (expected !== 1'bx) begin
                if (out !== expected)
                    $fatal(1, "Map mismatch abcd=%b expected=%b out=%b", bits, expected, out);
            end else if ((out !== 1'b0) && (out !== 1'b1)) begin
                $fatal(1, "Nonbinary output at dont-care cell abcd=%b out=%b", bits, out);
            end
            checks = checks + 1;
        end
    endtask

    initial begin
        for (i = 0; i < 16; i = i + 1) check_input(i[3:0]);
        for (i = 15; i >= 0; i = i - 1) check_input(i[3:0]);
        $display("PASS all %0d original-map checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
