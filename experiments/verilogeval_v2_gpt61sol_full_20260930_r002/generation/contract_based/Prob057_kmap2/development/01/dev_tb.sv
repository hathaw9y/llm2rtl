`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire out;
    integer i;
    integer checked = 0;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out));

    // Entries follow the original ab columns: 00, 01, 11, 10.
    function automatic logic map_expected(input logic [1:0] ab,
                                          input logic [1:0] cd);
        logic [3:0] row;
        integer column;
        begin
            case (cd)
                2'b00: row = 4'b1011;
                2'b01: row = 4'b1001;
                2'b11: row = 4'b1110;
                2'b10: row = 4'b0011;
                default: row = 4'bxxxx;
            endcase
            case (ab)
                2'b00: column = 0;
                2'b01: column = 1;
                2'b11: column = 2;
                2'b10: column = 3;
                default: column = 0;
            endcase
            map_expected = row[column];
        end
    endfunction

    task automatic check_input(input logic [3:0] bits);
        logic expected;
        begin
            {a,b,c,d} = bits;
            expected = map_expected(bits[3:2], bits[1:0]);
            #1;
            if (out !== expected)
                $fatal(1, "Mismatch ab=%b cd=%b expected=%b actual=%b", bits[3:2], bits[1:0], expected, out);
            checked = checked + 1;
        end
    endtask

    initial begin
        for (i = 0; i < 16; i = i + 1) check_input(i[3:0]);
        for (i = 15; i >= 0; i = i - 1) check_input(i[3:0]);
        $display("PASS: %0d K-map checks covering every binary input", checked);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
