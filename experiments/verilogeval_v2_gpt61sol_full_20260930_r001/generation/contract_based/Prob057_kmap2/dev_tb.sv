module dev_tb;
    logic a, b, c, d;
    wire out;
    logic expected;
    integer i, pass_index, checks;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out));

    // Literal K-map row vectors in column order ab=00,01,11,10.
    function automatic logic map_value(input logic [1:0] ab,
                                        input logic [1:0] cd);
        logic [0:3] row_values;
        integer column_index;
        begin
            case (cd)
                2'b00: row_values = 4'b1101;
                2'b01: row_values = 4'b1001;
                2'b11: row_values = 4'b0111;
                2'b10: row_values = 4'b1100;
                default: row_values = 4'bxxxx;
            endcase
            case (ab)
                2'b00: column_index = 0;
                2'b01: column_index = 1;
                2'b11: column_index = 2;
                2'b10: column_index = 3;
                default: column_index = 0;
            endcase
            map_value = row_values[column_index];
        end
    endfunction

    initial begin
        checks = 0;
        for (pass_index = 0; pass_index < 2; pass_index = pass_index + 1) begin
            for (i = 0; i < 16; i = i + 1) begin
                if (pass_index == 0) {a,b,c,d} = 4'(i);
                else {a,b,c,d} = 4'(15-i);
                expected = map_value({a,b}, {c,d});
                #1;
                if (out !== expected)
                    $fatal(1, "FAIL abcd=%b expected=%b actual=%b", {a,b,c,d}, expected, out);
                checks = checks + 1;
            end
        end
        $display("PASS: %0d checks, all 16 input combinations in both directions", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
