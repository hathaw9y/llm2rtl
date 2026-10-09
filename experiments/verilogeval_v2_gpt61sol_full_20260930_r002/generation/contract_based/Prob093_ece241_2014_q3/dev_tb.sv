`timescale 1ns/1ps
module dev_tb;
    logic c, d;
    wire [3:0] mux_in;
    logic [3:0] expected;
    logic [3:0] gray_row;
    integer pattern, selector, pass_index, checks;
    TopModule dut (.c(c), .d(d), .mux_in(mux_in));

    initial begin
        #100;
        $fatal(1, "Timeout");
    end

    initial begin
        checks = 0;
        for (pass_index = 0; pass_index < 2; pass_index = pass_index + 1) begin
            for (pattern = 0; pattern < 4; pattern = pattern + 1) begin
                if (pass_index == 0) {c,d} = pattern[1:0];
                else {c,d} = 2'b11 ^ pattern[1:0];
                // Literal K-map rows: bits [3:0] correspond to ab=00,01,11,10.
                case ({c,d})
                    2'b00: gray_row = 4'b0001;
                    2'b01: gray_row = 4'b1000;
                    2'b11: gray_row = 4'b1011;
                    2'b10: gray_row = 4'b1001;
                    default: $fatal(1, "Unexpected stimulus");
                endcase
                expected = {gray_row[1], gray_row[0], gray_row[2], gray_row[3]};
                #1;
                if (mux_in !== expected)
                    $fatal(1, "cd=%b%b expected=%b actual=%b", c,d,expected,mux_in);
                for (selector = 0; selector < 4; selector = selector + 1) begin
                    if (mux_in[selector] !== expected[selector])
                        $fatal(1, "K-map mismatch cd=%b%b ab=%b", c,d,selector[1:0]);
                    checks = checks + 1;
                end
            end
        end
        $display("PASS all %0d K-map selections and vector comparisons", checks);
        $finish;
    end
endmodule
